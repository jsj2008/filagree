#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import <Cocoa/Cocoa.h>
#import <objc/objc-class.h>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <OpenAL/al.h>
#include <OpenAL/alc.h>
#include <OpenGL/gl.h>

#include "struct.h"
#include "util.h"
#include "variable.h"
#include "vm.h"
#include "hal.h"
#include "struct.h"
#include "file.h"

static NSWindow *window = NULL;

void hal_loop(struct context *context) {
//    [NSApp run];
CFRunLoopRun();
}

@interface GLView : NSOpenGLView {
    const struct variable *shape;
}
@end

@implementation GLView

- (id)initWithFrame:(NSRect)frameRect
{
    NSOpenGLPixelFormatAttribute attr[] =
	{
        NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFAColorSize, (NSOpenGLPixelFormatAttribute) 32,
		NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute) 23,
		(NSOpenGLPixelFormatAttribute) 0
	};
	NSOpenGLPixelFormat *nsglFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attr];
	
    self = [super initWithFrame:frameRect pixelFormat:nsglFormat];
	return self;
}

- (void)setShape:(const struct variable *)ape {
    self->shape = ape;
}

- (void)prepareOpenGL
{
    glMatrixMode(GL_MODELVIEW);
	glClearColor(0, 0, .25, 0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glLoadIdentity();
	
    glShadeModel(GL_SMOOTH);
	glClearDepth(1.0f);
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LEQUAL);
	glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
}

- (float)get_float:(const struct variable *)point at:(uint32_t)i
{
    const struct variable *f = (const struct variable*)array_get(point->list.ordered, i);
    return f->floater;
}

- (void)drawRect:(NSRect)rect
{
    //    assert_message(shape->type == VAR_LST, "shape not list");
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
    glColor3f(1.0f, 0.85f, 0.35f);
    glBegin(GL_TRIANGLES);
    {
        if (NULL == self->shape) {
            glVertex3f(  0.0,  0.6, 0.0);
            glVertex3f( -0.2, -0.3, 0.0);
            glVertex3f(  0.2, -0.3 ,0.0);
        } else {
            for (uint32_t i=0; i<self->shape->list.ordered->length; i++) {
                const struct variable *point = (const struct variable*)array_get(self->shape->list.ordered, i);
                assert_message(point->type == VAR_LST, "point not list");
                float x = [self get_float:point at:0];
                float y = [self get_float:point at:1];
                float z = [self get_float:point at:2];
                glVertex3f( x, y, z);
            }
        }
    }
    glEnd();
    [[self openGLContext] flushBuffer];
}

@end

void hal_graphics(const struct variable *shape)
{
    NSView *content = [window contentView];
    NSRect rect = [content frame];
    GLView *graph = [[GLView alloc] initWithFrame:rect];
    [graph setShape:shape];
    [graph drawRect:rect];
    [content addSubview:graph];
}

void add_graphics()
{
    NSView *content = [window contentView];
    NSRect rect = [content frame];
    //rect.size.width /= 2;
    GLView *graph = [[GLView alloc] initWithFrame:rect];
    [graph drawRect:rect];
    [content addSubview:graph];
}


void hal_image()
{
    NSView *content = [window contentView];
    NSRect rect = [content frame];
    rect.origin.x = rect.size.width/2;
    NSImageView *iv = [[NSImageView alloc] initWithFrame:rect];

    NSURL *url = [NSURL URLWithString:@"http://www.cgl.uwaterloo.ca/~csk/projects/starpatterns/noneuclidean/323ball.jpg"];
    NSImage *pic = [[NSImage alloc] initWithContentsOfURL:url];
    if (pic)
        [iv setImage:pic];
    [content addSubview:iv];
}

void hal_sound(const char *address)
{
    //NSURL *url = [NSURL URLWithString:@"http://www.wavlist.com/soundfx/011/duck-quack3.wav"];
    NSString *str = [NSString stringWithCString:address encoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:str];
    NSSound *sound = [[NSSound alloc] initWithContentsOfURL:url byReference:FALSE];
    [sound play];
}

struct Sound {
    short *samples;
	size_t buf_size;
    unsigned sample_rate;
    int seconds;
};

#define CASE_RETURN(err) case (err): return "##err"
const char* al_err_str(ALenum err) {
    switch(err) {
            CASE_RETURN(AL_NO_ERROR);
            CASE_RETURN(AL_INVALID_NAME);
            CASE_RETURN(AL_INVALID_ENUM);
            CASE_RETURN(AL_INVALID_VALUE);
            CASE_RETURN(AL_INVALID_OPERATION);
            CASE_RETURN(AL_OUT_OF_MEMORY);
    }
    return "unknown";
}
#undef CASE_RETURN

#define __al_check_error(file,line) \
do { \
ALenum err = alGetError(); \
for(; err!=AL_NO_ERROR; err=alGetError()) { \
printf("AL Error %s at %s:%d\n", al_err_str(err), file, line ); \
} \
}while(0)

#define al_check_error() \
__al_check_error(__FILE__, __LINE__)

/* initialize OpenAL */
ALuint init_al() {
	ALCdevice *dev = NULL;
	ALCcontext *ctx = NULL;

	const char *defname = alcGetString(NULL, ALC_DEFAULT_DEVICE_SPECIFIER);
    printf("Default ouput device: %s\n", defname);

	dev = alcOpenDevice(defname);
	ctx = alcCreateContext(dev, NULL);
	alcMakeContextCurrent(ctx);

	/* Create buffer to store samples */
	ALuint buf;
	alGenBuffers(1, &buf);
	al_check_error();
    return buf;
}

/* Dealloc OpenAL */
void exit_al() {
	ALCdevice *dev = NULL;
	ALCcontext *ctx = NULL;
	ctx = alcGetCurrentContext();
	dev = alcGetContextsDevice(ctx);

	alcMakeContextCurrent(NULL);
	alcDestroyContext(ctx);
	alcCloseDevice(dev);
}

void hal_sleep(int32_t miliseconds)
{
    struct timespec req={0};
    time_t sec = (int)(miliseconds/1000);
    miliseconds = miliseconds - (sec * 1000);
    req.tv_sec = sec;
    req.tv_nsec = miliseconds * 1000000L;
    while (nanosleep(&req,&req) == -1)
        continue;
}

#define SYNTH_SAMPLE_RATE 44100 // CD quality

void hal_synth(const uint8_t *bytes, uint32_t length)
{
    short *samples = (short*)bytes;
    uint32_t size = length / sizeof(short);
    float duration = size * 1.0f / SYNTH_SAMPLE_RATE;

    ALuint buf = init_al();
    /* Download buffer to OpenAL */
	alBufferData(buf, AL_FORMAT_MONO16, samples, size, SYNTH_SAMPLE_RATE);
	al_check_error();

	/* Set-up sound source and play buffer */
	ALuint src = 0;
	alGenSources(1, &src);
	alSourcei(src, AL_BUFFER, buf);
	alSourcePlay(src);

	/* While sound is playing, sleep */
	al_check_error();

    hal_sleep(duration*1000);

	exit_al();
}

#define QUEUEBUFFERCOUNT 2
#define QUEUEBUFFERSIZE 9999

ALvoid hal_audio_loop(ALvoid)
{
    ALCdevice   *pCaptureDevice;
    const       ALCchar *szDefaultCaptureDevice;
    ALint       lSamplesAvailable;
    ALchar      Buffer[QUEUEBUFFERSIZE];
    ALuint      SourceID, TempBufferID;
    ALuint      BufferID[QUEUEBUFFERCOUNT];
    ALuint      ulBuffersAvailable = QUEUEBUFFERCOUNT;
    ALuint      ulUnqueueCount, ulQueueCount;
    ALint       lLoop, lFormat, lFrequency, lBlockAlignment, lProcessed, lPlaying;
    ALboolean   bPlaying = AL_FALSE;
    ALboolean   bPlay = AL_FALSE;

    // does not setup the Wave Device's Audio Mixer to select a recording input or recording level.

	ALCdevice *dev = NULL;
	ALCcontext *ctx = NULL;

	const char *defname = alcGetString(NULL, ALC_DEFAULT_DEVICE_SPECIFIER);
    printf("Default ouput device: %s\n", defname);

	dev = alcOpenDevice(defname);
	ctx = alcCreateContext(dev, NULL);
	alcMakeContextCurrent(ctx);

    // Generate a Source and QUEUEBUFFERCOUNT Buffers for Queuing
    alGetError();
    alGenSources(1, &SourceID);

    for (lLoop = 0; lLoop < QUEUEBUFFERCOUNT; lLoop++)
        alGenBuffers(1, &BufferID[lLoop]);

    if (alGetError() != AL_NO_ERROR) {
        printf("Failed to generate Source and / or Buffers\n");
        return;
    }

    ulUnqueueCount = 0;
    ulQueueCount = 0;

    // Get list of available Capture Devices
    const ALchar *pDeviceList = alcGetString(NULL, ALC_CAPTURE_DEVICE_SPECIFIER);
    if (pDeviceList) {
        printf("Available Capture Devices are:-\n");

        while (*pDeviceList) {
            printf("%s\n", pDeviceList);
            pDeviceList += strlen(pDeviceList) + 1;
        }
    }

    szDefaultCaptureDevice = alcGetString(NULL, ALC_CAPTURE_DEFAULT_DEVICE_SPECIFIER);
    printf("\nDefault Capture Device is '%s'\n\n", szDefaultCaptureDevice);

    // The next call can fail if the WaveDevice does not support the requested format, so the application
    // should be prepared to try different formats in case of failure

    lFormat = AL_FORMAT_MONO16;
    lFrequency = 44100;
    lBlockAlignment = 2;

    long lTotalProcessed = 0;
    long lOldSamplesAvailable = 0;
    long lOldTotalProcessed = 0;

    pCaptureDevice = alcCaptureOpenDevice(szDefaultCaptureDevice, lFrequency, lFormat, lFrequency);
    if (pCaptureDevice) {
        printf("Opened '%s' Capture Device\n\n", alcGetString(pCaptureDevice, ALC_CAPTURE_DEVICE_SPECIFIER));

        printf("start capture\n");
        alcCaptureStart(pCaptureDevice);
        bPlay = AL_TRUE;

        for (;;) {
            //alcCaptureStop(pCaptureDevice);

            alGetError();
            alcGetIntegerv(pCaptureDevice, ALC_CAPTURE_SAMPLES, 1, &lSamplesAvailable);

            if ((lOldSamplesAvailable != lSamplesAvailable) || (lOldTotalProcessed != lTotalProcessed)) {
                printf("Samples available is %d, Buffers Processed %ld\n", lSamplesAvailable, lTotalProcessed);
                lOldSamplesAvailable = lSamplesAvailable;
                lOldTotalProcessed = lTotalProcessed;
            }

            // If the Source is (or should be) playing, get number of buffers processed
            // and check play status
            if (bPlaying) {
                alGetSourcei(SourceID, AL_BUFFERS_PROCESSED, &lProcessed);
                while (lProcessed) {
                    lTotalProcessed++;

                    // Unqueue the buffer
                    alSourceUnqueueBuffers(SourceID, 1, &TempBufferID);

                    // Update unqueue count
                    if (++ulUnqueueCount == QUEUEBUFFERCOUNT)
                        ulUnqueueCount = 0;

                    // Increment buffers available
                    ulBuffersAvailable++;

                    lProcessed--;
                }

                // If the Source has stopped (been starved of data) it will need to be
                // restarted
                alGetSourcei(SourceID, AL_SOURCE_STATE, &lPlaying);
                if (lPlaying == AL_STOPPED) {
                    printf("Buffer Stopped, Buffers Available is %d\n", ulBuffersAvailable);
                    bPlay = AL_TRUE;
                }
            }

            if ((lSamplesAvailable > (QUEUEBUFFERSIZE / lBlockAlignment)) && !(ulBuffersAvailable)) {
                printf("underrun!\n");
            }

            // When we have enough data to fill our QUEUEBUFFERSIZE byte buffer, grab the samples
            else if ((lSamplesAvailable > (QUEUEBUFFERSIZE / lBlockAlignment)) && (ulBuffersAvailable)) {
                // Consume Samples
                alcCaptureSamples(pCaptureDevice, Buffer, QUEUEBUFFERSIZE / lBlockAlignment);
                alBufferData(BufferID[ulQueueCount], lFormat, Buffer, QUEUEBUFFERSIZE, lFrequency);

                // Queue the buffer, and mark buffer as queued
                alSourceQueueBuffers(SourceID, 1, &BufferID[ulQueueCount]);
                if (++ulQueueCount == QUEUEBUFFERCOUNT)
                    ulQueueCount = 0;

                // Decrement buffers available
                ulBuffersAvailable--;

                // If we need to start the Source do it now IF AND ONLY IF we have queued at least 2 buffers
                if ((bPlay) && (ulBuffersAvailable <= (QUEUEBUFFERCOUNT - 2))) {
                    alSourcePlay(SourceID);
                    printf("Buffer Starting \n");
                    bPlaying = AL_TRUE;
                    bPlay = AL_FALSE;
                }
            }
        }
        alcCaptureCloseDevice(pCaptureDevice);
    } else
        printf("WaveDevice is unavailable, or does not supported the request format\n");

    alSourceStop(SourceID);
    alDeleteSources(1, &SourceID);
    for (lLoop = 0; lLoop < QUEUEBUFFERCOUNT; lLoop++)
        alDeleteBuffers(1, &BufferID[lLoop]);
}

NSRect whereAmI(int x, int y, int w, int h)
{
    NSView *content = [window contentView];
    int frameHeight = [content frame].size.height;
    int y2 = frameHeight - y - h;
    //NSLog(@"whereAmI: %d - %d - %d = %d", frameHeight, y, h, y2);
    return NSMakeRect(x, y2, w, h);
}

void resize(NSControl *control,
            int32_t x, int32_t y,
            int32_t *w, int32_t *h)
{
    if (*w && *h)
        return;
    [control sizeToFit];
    NSSize size = control.frame.size;
    *w = size.width;
    *h = size.height;
    NSRect rect = whereAmI(x,y,*w,*h);
    [control setFrame:rect];
}

void *hal_label(struct variable *uictx,
                int32_t x, int32_t y,
                int32_t *w, int32_t *h,
                const char *str)
{
    NSRect rect = whereAmI(x,y,*w,*h);
    NSTextField *textField = [[NSTextField alloc] initWithFrame:rect];
    NSString *string = [NSString stringWithUTF8String:str];
    [textField setStringValue:string];
    [textField setBezeled:NO];
    [textField setDrawsBackground:NO];
    [textField setEditable:NO];
    [textField setSelectable:NO];
    NSView *content = [window contentView];
    [content addSubview:textField];

    resize(textField, x, y, w, h);
    return textField;
}

@interface Actionifier  : NSObject <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate>
{
    struct variable *logic;
    struct context *context;
    struct variable *uictx;
    struct variable *param;
    struct variable *data;
    NSTimer *timer;
}

-(void)setData:(struct variable*)value;
-(void)setTimer:(double)interval repeats:(bool)repeats;
-(IBAction)pressed:(id)sender;
-(void)timerCallback:(NSTimer*)timer;
-(void)callback;

@end

@implementation Actionifier

+(Actionifier*) fContext:(struct context *)f
               uiContext:(struct variable*)u
                callback:(struct variable*)c
                userData:(struct variable*)d
{
    Actionifier *bp = [Actionifier alloc];
    bp->logic = c;
    bp->context = f;
    bp->uictx = u;
    bp->data = d;
    bp->param = NULL;
    bp->timer = NULL;
    return bp;
}

-(void)setTimer:(double)interval repeats:(bool)repeats
{
    if (interval >= 1000)
        interval /= 1000;
    else
        interval *= -1;
    
    self->timer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                   target:self
                                                 selector:@selector(timerCallback:)
                                                 userInfo:nil
                                                  repeats:repeats];

    [[NSRunLoop mainRunLoop] addTimer:self->timer forMode:NSDefaultRunLoopMode];
}

-(void)setData:(struct variable*)value {
    self->data = value;
}

- (void)windowDidResize:(NSNotification*)notification
{
    NSWindow *window = [notification object];
	CGFloat w = [window frame].size.width;
	CGFloat h = [window frame].size.height;
    NSLog(@"resized to %f,%f", w, h);
}

- (id)          tableView:(NSTableView *) aTableView
objectValueForTableColumn:(NSTableColumn *) aTableColumn
                      row:(long) rowIndex {
    struct variable *item = array_get(self->data->list.ordered, rowIndex);
    char name[VV_SIZE];
    variable_value_str(self->context, item, name);
    return [NSString stringWithUTF8String:name];
}

- (long)numberOfRowsInTableView:(NSTableView *)aTableView {
    return self->data->list.ordered->length;
}

- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
    NSTableView* table = [notification object];
    int row = [table selectedRow];
    if (row == -1)
        return;
    self->param = variable_new_int(self->context, row);
    [self pressed:notification];
}

-(IBAction)pressed:(id)sender {
    [self callback];
}

-(void)timerCallback:(NSTimer*)timer {
    [self callback];
}

-(void)callback
{
    if (self->logic && self->logic->type != VAR_NIL)
    {
        gil_lock(self->context, "pressed");
        vm_call(self->context, self->logic, self->uictx, self->param, NULL);
        gil_unlock(self->context, "pressed");
    }
}

@end // Actionifier implementation

void *hal_button(struct context *context,
                 struct variable *uictx,
                 int32_t x, int32_t y,
                 int32_t *w, int32_t *h,
                 struct variable *logic,
                 const char *str, const char *img)
{
    NSView *content = [window contentView];
    NSRect rect = whereAmI(x,y,*w,*h);

    NSButton *my = [[NSButton alloc] initWithFrame:rect];
    [content addSubview: my];
    NSString *string = [NSString stringWithUTF8String:str];
    [my setTitle:string];

    if (img) {
        string = [NSString stringWithUTF8String:img];
        NSURL* url = [NSURL fileURLWithPath:string];
        NSImage *image = [[NSImage alloc] initWithContentsOfURL: url];
        [my setImage:image];
    }

    Actionifier *act = [Actionifier fContext:context
                                   uiContext:uictx
                                    callback:logic
                                    userData:NULL];
    [my setTarget:act];
    [my setAction:@selector(pressed:)];
    [my setButtonType:NSMomentaryLightButton];
    [my setBezelStyle:NSTexturedSquareBezelStyle];
    resize(my, x, y, w, h);
    return my;
}

void *hal_input(struct variable *uictx,
                int32_t x, int32_t y,
                int32_t *w, int32_t *h,
                const char *hint,
                bool multiline)
{
    NSView *content = [window contentView];
    *w = [content frame].size.width / 2;
    *h = 20;
    NSRect rect = whereAmI(x,y,*w,*h);
    NSString *string = hint ? [NSString stringWithUTF8String:hint] : NULL;

    NSView *textField;
    if (multiline)
        textField = [[NSTextView alloc] initWithFrame:rect];
    else
        textField = [[NSTextField alloc] initWithFrame:rect];
    if (NULL != string)
        [textField insertText:string];

    [content addSubview:textField];
    return textField;
}

struct variable *hal_ui_get(struct context *context, void *widget)
{
    NSObject *widget2 = (NSObject*)widget;
    if ([widget2 isKindOfClass:[NSTextField class]])
    {
        NSTextField *widget3 = (NSTextField*)widget;
        NSString *value = [widget3 stringValue];
        const char *value2 = [value UTF8String];
        return variable_new_str_chars(context, value2);
    }
    return variable_new_nil(context);
}

void hal_ui_set(void *widget, struct variable *value)
{
    NSObject *widget2 = (NSObject*)widget;

    if ([widget2 isKindOfClass:[NSTextField class]])
    {
        NSTextField *widget3 = (NSTextField*)widget;
        const char *value2 = byte_array_to_string(value->str);
        NSString *value3 = [NSString stringWithUTF8String:value2];
        [widget3 setStringValue:value3];
    }

    else if ([widget2 isKindOfClass:[NSTableView class]])
    {
        NSTableView *widget3 = (NSTableView*)widget;
        Actionifier *a = (Actionifier*)[widget3 delegate];
        [a setData:value];
        [widget3 reloadData];
    }
    else
        exit_message("unknown ui widget type");
}

void *hal_table(struct context *context,
                struct variable *uictx,
                int x, int y, int w, int h,
                struct variable *list,
                struct variable *logic)
{
    assert_message(list->type == VAR_LST, "not a list");

    NSView *content = [window contentView];
    NSRect rect = whereAmI(x,y,w,h);
    NSScrollView * tableContainer = [[NSScrollView alloc] initWithFrame:rect];
    w -= 16;
    rect = NSMakeRect(x, y, w, h);
    NSTableView *tableView = [[NSTableView alloc] initWithFrame:rect];
    NSTableColumn * column1 = [[NSTableColumn alloc] initWithIdentifier:@"Col1"];
    [tableView setHeaderView:nil];

    [tableView addTableColumn:column1];

    Actionifier *a = [Actionifier fContext:context
                                 uiContext:uictx
                                  callback:logic
                                  userData:list];
    [tableView setDelegate:a];
    [tableView setDataSource:(id<NSTableViewDataSource>)a];

    [tableContainer setDocumentView:tableView];
    [tableContainer setHasVerticalScroller:YES];
    [content addSubview:tableContainer];
    return tableView;
}

void *hal_window(struct context *context,
                struct variable *uictx,
                int32_t *w, int32_t *h,
                struct variable *logic)
{
    printf("hal_window\n");
    if (window) { // clear contents
        NSView *content = [window contentView];
        NSArray *subviews = [NSArray arrayWithArray:[content subviews]];
        [subviews makeObjectsPerformSelector:@selector(removeFromSuperviewWithoutNeedingDisplay)];
        [content setNeedsDisplay:YES];

        //[inputs removeAllObjects];
        NSSize size = [content frame].size;
        *w = size.width;
        *h = size.height;
        return window;
    }

    if ((NULL == w) || (NULL == h)) {
        NSLog(@"warning: zero-size window");
        *w = 240;
        *h = 320;
    }

    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    id menubar = [NSMenu new];
    id appMenuItem = [NSMenuItem new];
    [menubar addItem:appMenuItem];
    [NSApp setMainMenu:menubar];
    id appMenu = [NSMenu new];
    id appName = [[NSProcessInfo processInfo] processName];
    id quitTitle = [@"Quit " stringByAppendingString:appName];
    id quitMenuItem = [[NSMenuItem alloc] initWithTitle:quitTitle
                                                 action:@selector(terminate:)
                                          keyEquivalent:@"q"];
    [appMenu addItem:quitMenuItem];
    [appMenuItem setSubmenu:appMenu];
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, *w, *h)
                                         styleMask:NSTitledWindowMask |
              NSClosableWindowMask |
              NSMiniaturizableWindowMask |
              NSResizableWindowMask
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    [window cascadeTopLeftFromPoint:NSMakePoint(20,20)];
    [window setTitle:appName];
    [window makeKeyAndOrderFront:nil];
    Actionifier *a = [Actionifier fContext:context
                                 uiContext:uictx
                                  callback:logic
                                  userData:NULL];
    [window setDelegate:a];

    NSString *path = @"icon.png";
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSImage *icon = [[NSImage alloc] initWithContentsOfFile:path];
        if (icon)
            [NSApp setApplicationIconImage:icon];
    }

    [NSApp activateIgnoringOtherApps:YES];

    return window;
}

void hal_save(struct context *context, const struct byte_array *key, const struct variable *value)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    const char *key2 = byte_array_to_string(key);
    NSString *key3 = [NSString stringWithUTF8String:key2];

    struct byte_array *bits = variable_serialize(context, NULL, value);
    NSData *value2 = [NSData dataWithBytes:bits->data length:bits->length];

    byte_array_reset(bits);
    struct variable *tst = variable_deserialize(context, bits);
    char buf[VV_SIZE];
    NSLog(@"tst = %s", variable_value_str(context, tst, buf));

    [defaults setObject:value2 forKey:key3];
    [defaults synchronize];
}

struct variable *hal_load(struct context *context, const struct byte_array *key)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    const char *key2 = byte_array_to_string(key);
    NSString *key3 = [NSString stringWithUTF8String:key2];
    NSData *value2 = [defaults dataForKey:key3];
    if (NULL == value2)
        return variable_new_nil(context);
    struct byte_array bits = {(uint8_t*)[value2 bytes], NULL, [value2 length]};
    bits.current = bits.data;

    return variable_deserialize(context, &bits);
}

void hal_print(const char *str) {
    NSLog(@"%s", str);
}

struct file_thread {
    struct context *context;
    struct variable *listener;
};

void file_listener_callback(ConstFSEventStreamRef streamRef,
                            void *clientCallBackInfo,
                            size_t numEvents,
                            void *eventPaths,
                            const FSEventStreamEventFlags eventFlags[],
                            const FSEventStreamEventId eventIds[])
{
    DEBUGPRINT("file_listener_callback\n");
    int i;
    char **paths = eventPaths;
    struct file_thread *thread = (struct file_thread*)clientCallBackInfo;

    gil_lock(thread->context, "file_listener_callback");

    for (i=0; i<numEvents; i++) {
        /*
         FSEventStreamEventFlags event = eventFlags[i];
         if (event & kFSEventStreamEventFlagItemCreated)     DEBUGPRINT("\t\tcreated\n");
         if (event & kFSEventStreamEventFlagItemRenamed)     DEBUGPRINT("\t\trenamed\n");
         if (event & kFSEventStreamEventFlagItemRemoved)     DEBUGPRINT("\t\tdeleted\n");
         if (event & kFSEventStreamEventFlagItemModified)    DEBUGPRINT("\t\tmodified\n");
         */

        char *path = (char*)paths[i];
        int len = strlen(path) - 1;
        if (path[len] == '/') path[len] = 0; // pesky trailing slash
        struct variable *path3 = variable_new_str_chars(thread->context, path);

        struct variable *method2 = event_string(thread->context, FILED);
        struct variable *method3 = variable_map_get(thread->context, thread->listener, method2);

        long mod = file_modified(path);
        struct variable *mod2 = variable_new_int(thread->context, mod); // goes pop in 2038
        if ((NULL != method3) && (method3->type != VAR_NIL))
            vm_call(thread->context, method3, thread->listener, path3, mod2);
    }

    gil_unlock(thread->context, "file_listener_callback");
}

void hal_file_listen(struct context *context, const char *path, struct variable *listener)
{
    DEBUGPRINT("hal_file_listen %s\n", path);

    struct file_thread *ft = (struct file_thread*)malloc((sizeof(struct file_thread)));
    ft->context = context;
    ft->listener = listener;

    CFStringRef path2 = CFStringCreateWithCString(NULL, path, kCFStringEncodingUTF8);
    CFArrayRef pathsToWatch = CFArrayCreate(NULL, (const void **)&path2, 1, NULL);

    FSEventStreamContext fsc = {0, ft, NULL, NULL, NULL};
    FSEventStreamRef stream;
    CFAbsoluteTime latency = 1.0; // seconds

    stream = FSEventStreamCreate(NULL,
                                 &file_listener_callback,
                                 &fsc,
                                 pathsToWatch,
                                 kFSEventStreamEventIdSinceNow, // Or a previous event ID
                                 latency,
                                 kFSEventStreamCreateFlagNone
                                 );

    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	FSEventStreamStart(stream);
	//CFRunLoopRun();
}

/////// timer

void hal_timer(struct context *context,
               int32_t milliseconds,
               struct variable *logic,
               bool repeats)
{
    Actionifier *actionifier = [Actionifier fContext:context
                                           uiContext:NULL
                                            callback:logic
                                            userData:NULL];

    [actionifier setTimer:milliseconds repeats:repeats];
}