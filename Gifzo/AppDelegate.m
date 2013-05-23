//
//  AppDelegate.m
//  Gifzo
//
//  Created by uiureo on 13/05/02.
//  Copyright (c) 2013年 uiureo. All rights reserved.
//

#import "AppDelegate.h"
#import "BorderlessWindow.h"
#import "Uploader.h"

@implementation AppDelegate {
    NSMutableArray *_windows;
    BOOL _isRecording, _recordingDidFinished;
    NSURL *_tempURL;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.recorder = [[Recorder alloc] init];
    self.recorder.delegate = self;
    _isRecording = NO;

    // movファイル書き出し用のテンポラリディレクトリの初期化
    NSString *tempName = [self generateTempName];
    _tempURL = [NSURL fileURLWithPath:[tempName stringByAppendingPathExtension:@"mov"]];

    [self startCropRect];
}

- (void)startRecording:(NSRect)cropRect screen:(NSScreen *)screen
{
    [self.recorder startRecordingWithOutputURL:_tempURL croppingRect:cropRect screen:screen];

    _isRecording = YES;
}

#define kShadyWindowLevel   (NSScreenSaverWindowLevel + 1)

- (void)startCropRect
{
    _windows = [NSMutableArray array];

    for (NSScreen *screen in [NSScreen screens]) {
        NSRect frame = [screen frame];
        NSWindow *window = [[BorderlessWindow alloc] initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
        [window setBackgroundColor:[NSColor clearColor]];
        [window setOpaque:NO];
        [window setLevel:kShadyWindowLevel];
        [window setReleasedWhenClosed:YES];

        DrawMouseBoxView *drawMouseBoxView = [[DrawMouseBoxView alloc] initWithFrame:frame];
        drawMouseBoxView.screen = screen;
        drawMouseBoxView.delegate = self;

        [window setContentView:drawMouseBoxView];
        [window makeKeyAndOrderFront:self];
        [_windows addObject:window];
    }
}

#pragma mark - DrawMouseBoxViewDelegate
- (void)startRecordingKeyDidPressedInView:(DrawMouseBoxView *)view withRect:(NSRect)rect screen:(NSScreen *)screen
{
    if (_recordingDidFinished) return;

    if (_isRecording) {
        [self.recorder finishRecording];
        _recordingDidFinished = YES;
    } else {
        [self startRecording:rect screen:screen];
    }
}

#pragma mark - RecorderDelegate
- (void)recorder:(Recorder *)recorder didRecordedWithOutputURL:(NSURL *)outputFileURL
{
    for (NSWindow *window in _windows) {
        [window close];
    }

    [self convertFromMOVToMP4:outputFileURL];
}

- (void)convertFromMOVToMP4:(NSURL *)outputFileURL
{
    AVAsset *asset = [AVAsset assetWithURL:outputFileURL];
    AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetPassthrough];

    NSString *tempName = [self generateTempName];

    exportSession.outputURL = [NSURL fileURLWithPath:[tempName stringByAppendingPathExtension:@"mp4"]];
    exportSession.outputFileType = AVFileTypeMPEG4;

    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        switch ([exportSession status]) {
            case AVAssetExportSessionStatusCompleted:
                NSLog(@"Export completed: %@", exportSession.outputURL);

                [self upload:exportSession.outputURL];

                break;
            case AVAssetExportSessionStatusFailed:
                NSLog(@"Export failed: %@", [[exportSession error] localizedDescription]);

                [NSApp terminate:nil];
                break;
            case AVAssetExportSessionStatusCancelled:
                NSLog(@"Export canceled");

                [NSApp terminate:nil];
                break;
            default:
                break;
        }
    }];
}

- (NSString *)generateTempName
{
    char *tempNameBytes = tempnam([NSTemporaryDirectory() fileSystemRepresentation], "Gifzo_");
    NSString *tempName = [[NSString alloc] initWithBytesNoCopy:tempNameBytes length:strlen(tempNameBytes) encoding:NSUTF8StringEncoding freeWhenDone:YES];

    return tempName;
}

// mp4ファイルをmultipart uploadする
- (void)upload:(NSURL *)videoURL
{
    [[[Uploader alloc] init] uploadVideo:videoURL completion:^(NSURL *gifURL, NSError *error) {
        if (gifURL) {
            [self copyToPasteboard:[gifURL absoluteString]];
            [[NSWorkspace sharedWorkspace] openURL:gifURL];

            [NSApp terminate:nil];
        }
        else if (error) {
            NSLog(@"Cannot upload file: %@", [error description]);

            [NSApp terminate:nil];
        }
    }];
}

- (void)copyToPasteboard:(NSString *)urlString
{
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard declareTypes:[NSArray arrayWithObjects:NSPasteboardTypeString, nil] owner:nil];
    [pasteboard setString:urlString forType:NSPasteboardTypeString];
}
@end
