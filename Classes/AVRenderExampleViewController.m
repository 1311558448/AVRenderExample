//
//  AVRenderExampleViewController.m
//  AVRenderExample
//
//  Created by Moses DeJong on 5/16/11.
//
//  See AVRenderExampleViewController.h for description of this example app.

#import "AVRenderExampleViewController.h"

#import "AVAnimatorView.h"

#import "MovieControlsViewController.h"
#import "MovieControlsAdaptor.h"

#import "AVAnimatorMedia.h"

#import "AV7zAppResourceLoader.h"

#import "AVMvidFrameDecoder.h"

#import "AVFileUtil.h"

#import "AVOfflineComposition.h"

@implementation AVRenderExampleViewController

@synthesize window = m_window;
@synthesize renderButton = m_renderButton;
@synthesize animatorView = m_animatorView;
@synthesize movieControlsViewController = m_movieControlsViewController;
@synthesize movieControlsAdaptor = m_movieControlsAdaptor;
@synthesize composition = m_composition;

- (void)dealloc {
  self.window = nil;
  self.renderButton = nil;
  self.animatorView = nil;
  self.movieControlsViewController = nil;
  self.movieControlsAdaptor = nil;
  self.composition = nil;
  [super dealloc];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
  [super viewDidLoad];
  NSAssert(self.renderButton, @"renderButton not set in NIB");
}

- (void) loadAnimatorView
{
  // The UIWindow the movie controls will be loaded into can't be null at this point
  UIWindow *window = self.view.window;
  NSAssert(window != nil, @"window is nil");
  self.window = window;

  // Don't use this view and view controller, make the movie controllers the primary view
  [self.view removeFromSuperview];
  
  CGRect frame = CGRectMake(0, 0, 480, 320);
  self.animatorView = [AVAnimatorView aVAnimatorViewWithFrame:frame];
  
  // Create Render Object
  
  NSString *resFilename = @"Comp.plist";
  
  NSDictionary *plistDict = (NSDictionary*) [AVOfflineComposition readPlist:resFilename];
  
  AVOfflineComposition *comp = [AVOfflineComposition aVOfflineComposition];
  
  self.composition = comp;
  
  [self setupNotification];
  
  NSLog(@"start rendering lossless movie in background");
  
  [comp compose:plistDict];

  return;
}

- (void) stopAnimator
{
  if (self.movieControlsAdaptor != nil) {
    [self.movieControlsAdaptor stopAnimator];
    self.movieControlsAdaptor = nil;
    self.movieControlsViewController.mainWindow = nil;
  }
  
  {
    // Remove the very large comp file rendered to disk. The
    // next time a render was done the logic would remove
    // the previous output comp anyway, but since this file is so
    // very large (more than 2 gigabytes) it is better to remove
    // it right away to avoid leaving it on disk on accident.
    
    AVAnimatorMedia *media = self.animatorView.media;
    
    AVMvidFrameDecoder *frameDecoder = (AVMvidFrameDecoder*) media.frameDecoder;
    
    NSString *tmpCompPath = frameDecoder.filePath;
    
    {
      BOOL worked;
      worked = [[NSFileManager defaultManager] removeItemAtPath:tmpCompPath error:nil];
      NSAssert(worked, @"could not remove tmp file");
    }
  }
  
  [self.animatorView removeFromSuperview];    
	self.animatorView = nil;
  
	self.movieControlsViewController = nil;
  
	[self.window addSubview:self.view];  
}

// Notification indicates that all animations in a loop are now finished

- (void)animatorDoneNotification:(NSNotification*)notification {
  NSLog( @"animatorDoneNotification" );
  
  // Unlink all notifications
  
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
	[self stopAnimator];  
}

- (IBAction) renderButton:(id)target
{
  [self loadAnimatorView];
  return;
}

- (void) setupNotification
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(finishedLoadNotification:) 
                                               name:AVOfflineCompositionCompletedNotification
                                             object:self.composition];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(failedToLoadNotification:) 
                                               name:AVOfflineCompositionFailedNotification
                                             object:self.composition];  
}

- (void) finishedLoadNotification:(NSNotification*)notification
{
  NSLog(@"finished rendering lossless movie");
  
  NSString *filename = self.composition.destination;
  
  AVAnimatorMedia *media = [AVAnimatorMedia aVAnimatorMedia];
  
  // Create res loader
  
  AVAppResourceLoader *resLoader = [AVAppResourceLoader aVAppResourceLoader];
  // Phony resource name, becomes no-op since the comp file exists already
  resLoader.movieFilename = filename;
  
	media.resourceLoader = resLoader;
  media.frameDecoder = [AVMvidFrameDecoder aVMvidFrameDecoder];
    
  AVMvidFrameDecoder *frameDecoder = [AVMvidFrameDecoder aVMvidFrameDecoder];
  
  BOOL worked;
  worked = [frameDecoder openForReading:filename];
	NSAssert(worked, @"frameDecoder openForReading failed");

  
	self.movieControlsViewController = [MovieControlsViewController movieControlsViewController:self.animatorView];
  
  // A MovieControlsViewController can only be placed inside a toplevel window!
  // Unlike a normal controller, you can't invoke [window addSubview:movieControlsViewController.view]
  // to place a MovieControlsViewController in a window. Just set the mainWindow property instead.
  
  self.movieControlsViewController.mainWindow = self.window;
  
  self.movieControlsAdaptor = [MovieControlsAdaptor movieControlsAdaptor];
  self.movieControlsAdaptor.animatorView = self.animatorView;
  self.movieControlsAdaptor.movieControlsViewController = self.movieControlsViewController;
  
  // Associate Media with the view that it will be rendered into
  
  [self.animatorView attachMedia:media];
  
  // This object needs to listen for the AVAnimatorDoneNotification to update the GUI
  // after movie loops are finished playing.
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(animatorDoneNotification:) 
                                               name:AVAnimatorDoneNotification
                                             object:self.animatorView.media];  
  
  [self.movieControlsAdaptor startAnimator];
  
  return;
}

- (void) failedToLoadNotification:(NSNotification*)notification
{
  AVOfflineComposition *comp = (AVOfflineComposition*)notification.object;
  
  NSString *errorString = comp.errorString;
  
  NSLog(@"failed rendering lossless movie: \"%@\"", errorString);
}

@end
