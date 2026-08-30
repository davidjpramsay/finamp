#import "NightAudioBridge.h"

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <MediaToolbox/MediaToolbox.h>
#import <objc/runtime.h>
#import <stdatomic.h>

#if __has_include(<just_audio/AudioPlayer.h>)
#import <just_audio/AudioPlayer.h>
#else
@import just_audio;
#endif

#define NightSpectrumBandCount 32
#define NightEQBandCount 5
#define NightFFTSize 512
static const float NightEQFrequencies[] = {60.0f, 250.0f, 1000.0f, 4000.0f, 12000.0f};

static _Atomic(float) gNightSpectrum[NightSpectrumBandCount];
static _Atomic(float) gNightEQGains[NightEQBandCount];
static atomic_bool gNightEQEnabled;

typedef struct {
    Float64 sampleRate;
    UInt32 channelCount;
    UInt32 captureCount;
    bool formatSupported;
    float capture[NightFFTSize];
    float *window;
    float *windowed;
    float *real;
    float *imaginary;
    float *magnitudes;
    FFTSetup fftSetup;
    float coefficients[NightEQBandCount][5];
    float state[2][NightEQBandCount][2];
    float appliedGains[NightEQBandCount];
    bool equalizerWasEnabled;
} NightTapContext;

static inline float NightClamp(float value, float lower, float upper) {
    return fminf(upper, fmaxf(lower, value));
}

static void NightUpdateEQCoefficients(NightTapContext *context) {
    if (context->sampleRate <= 0) return;

    for (NSUInteger band = 0; band < NightEQBandCount; band++) {
        float gain = atomic_load_explicit(&gNightEQGains[band], memory_order_relaxed);
        context->appliedGains[band] = gain;

        float frequency = fminf(NightEQFrequencies[band], (float)context->sampleRate * 0.44f);
        float a = powf(10.0f, gain / 40.0f);
        float omega = 2.0f * (float)M_PI * frequency / (float)context->sampleRate;
        float alpha = sinf(omega) / 2.0f;
        float cosine = cosf(omega);
        float a0 = 1.0f + alpha / a;

        context->coefficients[band][0] = (1.0f + alpha * a) / a0;
        context->coefficients[band][1] = (-2.0f * cosine) / a0;
        context->coefficients[band][2] = (1.0f - alpha * a) / a0;
        context->coefficients[band][3] = (-2.0f * cosine) / a0;
        context->coefficients[band][4] = (1.0f - alpha / a) / a0;
    }
}

static inline float NightProcessEQSample(NightTapContext *context, float sample, NSUInteger channel) {
    float output = sample;
    for (NSUInteger band = 0; band < NightEQBandCount; band++) {
        float *coefficient = context->coefficients[band];
        float *state = context->state[channel][band];
        float next = coefficient[0] * output + state[0];
        state[0] = coefficient[1] * output - coefficient[3] * next + state[1];
        state[1] = coefficient[2] * output - coefficient[4] * next;
        output = next;
    }
    return NightClamp(output, -1.0f, 1.0f);
}

static void NightPublishSpectrum(NightTapContext *context) {
    if (context->fftSetup == NULL) return;

    vDSP_vmul(context->capture, 1, context->window, 1, context->windowed, 1, NightFFTSize);
    DSPSplitComplex split = {.realp = context->real, .imagp = context->imaginary};
    vDSP_ctoz((DSPComplex *)context->windowed, 2, &split, 1, NightFFTSize / 2);
    vDSP_fft_zrip(context->fftSetup, &split, 1, 9, FFT_FORWARD);
    vDSP_zvmags(&split, 1, context->magnitudes, 1, NightFFTSize / 2);

    const float minimumFrequency = 38.0f;
    const float maximumFrequency = fminf(18000.0f, (float)context->sampleRate * 0.48f);
    const float normalizer = (float)(NightFFTSize * NightFFTSize);

    for (NSUInteger band = 0; band < NightSpectrumBandCount; band++) {
        float startRatio = (float)band / (float)NightSpectrumBandCount;
        float endRatio = (float)(band + 1) / (float)NightSpectrumBandCount;
        float startFrequency = minimumFrequency * powf(maximumFrequency / minimumFrequency, startRatio);
        float endFrequency = minimumFrequency * powf(maximumFrequency / minimumFrequency, endRatio);
        NSUInteger startBin = MAX(1, (NSUInteger)floorf(startFrequency * NightFFTSize / context->sampleRate));
        NSUInteger endBin = MIN(NightFFTSize / 2 - 1, (NSUInteger)ceilf(endFrequency * NightFFTSize / context->sampleRate));

        float peak = 0.0f;
        for (NSUInteger bin = startBin; bin <= MAX(startBin, endBin); bin++) {
            peak = fmaxf(peak, context->magnitudes[bin] / normalizer);
        }
        float decibels = 10.0f * log10f(peak + 1.0e-12f);
        float value = NightClamp((decibels + 76.0f) / 76.0f, 0.0f, 1.0f);
        float previous = atomic_load_explicit(&gNightSpectrum[band], memory_order_relaxed);
        atomic_store_explicit(&gNightSpectrum[band], previous * 0.58f + value * 0.42f, memory_order_relaxed);
    }
}

static void NightTapInit(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut) {
    *tapStorageOut = clientInfo;
}

static void NightTapFinalize(MTAudioProcessingTapRef tap) {
    NightTapContext *context = MTAudioProcessingTapGetStorage(tap);
    if (context == NULL) return;
    if (context->fftSetup != NULL) vDSP_destroy_fftsetup(context->fftSetup);
    free(context->window);
    free(context->windowed);
    free(context->real);
    free(context->imaginary);
    free(context->magnitudes);
    free(context);
}

static void NightTapPrepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *format) {
    NightTapContext *context = MTAudioProcessingTapGetStorage(tap);
    if (context == NULL) return;

    context->sampleRate = format->mSampleRate;
    context->channelCount = MAX(1, format->mChannelsPerFrame);
    context->captureCount = 0;
    context->formatSupported =
        format->mFormatID == kAudioFormatLinearPCM &&
        (format->mFormatFlags & kAudioFormatFlagIsFloat) != 0 &&
        format->mBitsPerChannel == 32;
    if (!context->formatSupported) {
        NSLog(@"[FINAMP-NightAudio] Unsupported tap format; DSP safely bypassed");
        return;
    }
    context->fftSetup = vDSP_create_fftsetup(9, FFT_RADIX2);
    context->window = calloc(NightFFTSize, sizeof(float));
    context->windowed = calloc(NightFFTSize, sizeof(float));
    context->real = calloc(NightFFTSize / 2, sizeof(float));
    context->imaginary = calloc(NightFFTSize / 2, sizeof(float));
    context->magnitudes = calloc(NightFFTSize / 2, sizeof(float));
    vDSP_hann_window(context->window, NightFFTSize, vDSP_HANN_NORM);
    NightUpdateEQCoefficients(context);
}

static void NightTapUnprepare(MTAudioProcessingTapRef tap) {}

static void NightTapProcess(
    MTAudioProcessingTapRef tap,
    CMItemCount numberFrames,
    MTAudioProcessingTapFlags flags,
    AudioBufferList *bufferList,
    CMItemCount *numberFramesOut,
    MTAudioProcessingTapFlags *flagsOut
) {
    OSStatus status = MTAudioProcessingTapGetSourceAudio(
        tap,
        numberFrames,
        bufferList,
        flagsOut,
        NULL,
        numberFramesOut
    );
    if (status != noErr || *numberFramesOut == 0) return;

    NightTapContext *context = MTAudioProcessingTapGetStorage(tap);
    if (context == NULL || !context->formatSupported || bufferList->mNumberBuffers == 0) return;

    bool equalizerEnabled = atomic_load_explicit(&gNightEQEnabled, memory_order_relaxed);
    bool gainsChanged = false;
    for (NSUInteger band = 0; band < NightEQBandCount; band++) {
        float gain = atomic_load_explicit(&gNightEQGains[band], memory_order_relaxed);
        gainsChanged = gainsChanged || fabsf(gain - context->appliedGains[band]) > 0.01f;
    }
    if (gainsChanged) NightUpdateEQCoefficients(context);
    if (equalizerEnabled != context->equalizerWasEnabled) {
        memset(context->state, 0, sizeof(context->state));
        context->equalizerWasEnabled = equalizerEnabled;
    }

    UInt32 channelCount = MAX(1, context->channelCount);
    BOOL interleaved = bufferList->mNumberBuffers == 1 && channelCount > 1;
    UInt32 channelsToProcess = MIN((UInt32)2, interleaved ? channelCount : bufferList->mNumberBuffers);

    for (CMItemCount frame = 0; frame < *numberFramesOut; frame++) {
        float analysisSample = 0.0f;
        for (UInt32 channel = 0; channel < channelsToProcess; channel++) {
            AudioBuffer *buffer = interleaved ? &bufferList->mBuffers[0] : &bufferList->mBuffers[channel];
            if (buffer->mData == NULL) continue;
            float *samples = (float *)buffer->mData;
            NSUInteger sampleIndex = interleaved ? (NSUInteger)frame * channelCount + channel : (NSUInteger)frame;
            if (sampleIndex >= buffer->mDataByteSize / sizeof(float)) continue;
            float sample = samples[sampleIndex];
            if (channel == 0) analysisSample = sample;
            if (equalizerEnabled) samples[sampleIndex] = NightProcessEQSample(context, sample, channel);
        }

        context->capture[context->captureCount++] = analysisSample;
        if (context->captureCount == NightFFTSize) {
            NightPublishSpectrum(context);
            context->captureCount = 0;
        }
    }
}

@interface NightAudioBridge : NSObject <FlutterStreamHandler>
@property(nonatomic, strong) NSHashTable<AudioPlayer *> *players;
@property(nonatomic, copy, nullable) FlutterEventSink eventSink;
@property(nonatomic, strong, nullable) NSTimer *timer;
@property(nonatomic) NSUInteger tick;
@end

@implementation NightAudioBridge

+ (instancetype)sharedBridge {
    static NightAudioBridge *bridge;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bridge = [[NightAudioBridge alloc] init];
        bridge.players = [NSHashTable weakObjectsHashTable];
        atomic_init(&gNightEQEnabled, false);
        for (NSUInteger index = 0; index < NightSpectrumBandCount; index++) atomic_init(&gNightSpectrum[index], 0.0f);
        for (NSUInteger index = 0; index < NightEQBandCount; index++) atomic_init(&gNightEQGains[index], 0.0f);
    });
    return bridge;
}

- (void)setupWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    FlutterEventChannel *spectrumChannel = [FlutterEventChannel
        eventChannelWithName:@"finamp/night_audio/spectrum"
        binaryMessenger:messenger
    ];
    [spectrumChannel setStreamHandler:self];

    FlutterMethodChannel *controlChannel = [FlutterMethodChannel
        methodChannelWithName:@"finamp/night_audio/control"
        binaryMessenger:messenger
    ];
    __weak typeof(self) weakSelf = self;
    [controlChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
        [weakSelf handleControlCall:call result:result];
    }];

    self.timer = [NSTimer timerWithTimeInterval:0.05
                                         target:self
                                       selector:@selector(timerFired:)
                                       userInfo:nil
                                        repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)monitorPlayer:(AudioPlayer *)player {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.players addObject:player];
        [self attachTapIfPossible:player];
    });
}

- (void)timerFired:(NSTimer *)timer {
    self.tick += 1;
    if (self.tick % 8 == 0) {
        for (AudioPlayer *player in self.players) [self attachTapIfPossible:player];
    }

    if (self.eventSink == nil) return;
    NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithCapacity:NightSpectrumBandCount];
    for (NSUInteger index = 0; index < NightSpectrumBandCount; index++) {
        [values addObject:@(atomic_load_explicit(&gNightSpectrum[index], memory_order_relaxed))];
    }
    self.eventSink(values);
}

- (void)attachTapIfPossible:(AudioPlayer *)audioPlayer {
    AVPlayerItem *item = audioPlayer.player.currentItem;
    if (item == nil || objc_getAssociatedObject(item, @selector(attachTapIfPossible:)) != nil) return;

    AVAssetTrack *track = [[item.asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (track == nil) return;

    NightTapContext *context = calloc(1, sizeof(NightTapContext));
    MTAudioProcessingTapCallbacks callbacks = {
        .version = kMTAudioProcessingTapCallbacksVersion_0,
        .clientInfo = context,
        .init = NightTapInit,
        .finalize = NightTapFinalize,
        .prepare = NightTapPrepare,
        .unprepare = NightTapUnprepare,
        .process = NightTapProcess,
    };
    MTAudioProcessingTapRef tap = NULL;
    OSStatus status = MTAudioProcessingTapCreate(
        kCFAllocatorDefault,
        &callbacks,
        kMTAudioProcessingTapCreationFlag_PreEffects,
        &tap
    );
    if (status != noErr || tap == NULL) {
        free(context);
        return;
    }

    AVMutableAudioMix *mix = item.audioMix != nil ? [item.audioMix mutableCopy] : [AVMutableAudioMix audioMix];
    NSMutableArray<AVAudioMixInputParameters *> *parameters = [mix.inputParameters mutableCopy] ?: [NSMutableArray array];
    NSUInteger existingIndex = [parameters indexOfObjectPassingTest:^BOOL(
        AVAudioMixInputParameters *candidate,
        NSUInteger index,
        BOOL *stop
    ) {
        return candidate.trackID == track.trackID;
    }];
    AVMutableAudioMixInputParameters *input;
    if (existingIndex == NSNotFound) {
        input = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:track];
        [parameters addObject:input];
    } else {
        AVAudioMixInputParameters *existing = parameters[existingIndex];
        if (existing.audioTapProcessor != NULL) {
            CFRelease(tap);
            NSLog(@"[FINAMP-NightAudio] Existing audio tap retained; DSP safely bypassed");
            return;
        }
        input = [existing mutableCopy];
        parameters[existingIndex] = input;
    }
    input.audioTapProcessor = tap;
    CFRelease(tap);

    mix.inputParameters = parameters;
    item.audioMix = mix;
    objc_setAssociatedObject(item, @selector(attachTapIfPossible:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[FINAMP-NightAudio] Live spectrum tap attached");
}

- (void)handleControlCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([call.method isEqualToString:@"getEqualizer"]) {
        NSMutableArray *gains = [NSMutableArray arrayWithCapacity:NightEQBandCount];
        NSMutableArray *frequencies = [NSMutableArray arrayWithCapacity:NightEQBandCount];
        for (NSUInteger index = 0; index < NightEQBandCount; index++) {
            [gains addObject:@(atomic_load_explicit(&gNightEQGains[index], memory_order_relaxed))];
            [frequencies addObject:@(NightEQFrequencies[index])];
        }
        result(@{
            @"supported": @YES,
            @"enabled": @(atomic_load_explicit(&gNightEQEnabled, memory_order_relaxed)),
            @"minimumGain": @(-12.0),
            @"maximumGain": @(12.0),
            @"frequencies": frequencies,
            @"gains": gains,
        });
        return;
    }

    NSDictionary *arguments = [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments : @{};
    if ([call.method isEqualToString:@"setEqualizerEnabled"]) {
        atomic_store_explicit(&gNightEQEnabled, [arguments[@"enabled"] boolValue], memory_order_relaxed);
        result(nil);
    } else if ([call.method isEqualToString:@"setEqualizerBand"]) {
        NSInteger index = [arguments[@"index"] integerValue];
        float gain = NightClamp([arguments[@"gain"] floatValue], -12.0f, 12.0f);
        if (index < 0 || index >= NightEQBandCount) {
            result([FlutterError errorWithCode:@"invalid_band" message:@"Equalizer band is out of range" details:nil]);
            return;
        }
        atomic_store_explicit(&gNightEQGains[index], gain, memory_order_relaxed);
        result(nil);
    } else if ([call.method isEqualToString:@"resetEqualizer"]) {
        for (NSUInteger index = 0; index < NightEQBandCount; index++) {
            atomic_store_explicit(&gNightEQGains[index], 0.0f, memory_order_relaxed);
        }
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    self.eventSink = events;
    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

@end

@implementation AudioPlayer (FinampNightAudio)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(
            self,
            @selector(initWithRegistrar:playerId:loadConfiguration:useLazyPreparation:)
        );
        Method replacement = class_getInstanceMethod(
            self,
            @selector(night_initWithRegistrar:playerId:loadConfiguration:useLazyPreparation:)
        );
        method_exchangeImplementations(original, replacement);
    });
}

- (instancetype)night_initWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar
                                playerId:(NSString *)playerId
                       loadConfiguration:(NSDictionary *)loadConfiguration
                      useLazyPreparation:(BOOL)useLazyPreparation {
    AudioPlayer *player = [self night_initWithRegistrar:registrar
                                               playerId:playerId
                                      loadConfiguration:loadConfiguration
                                     useLazyPreparation:useLazyPreparation];
    [[NightAudioBridge sharedBridge] monitorPlayer:player];
    return player;
}

@end

void NightAudioBridgeSetup(NSObject<FlutterBinaryMessenger> *messenger) {
    [[NightAudioBridge sharedBridge] setupWithMessenger:messenger];
}
