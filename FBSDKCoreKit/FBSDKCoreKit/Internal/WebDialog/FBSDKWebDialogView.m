// Copyright (c) 2014-present, Facebook, Inc. All rights reserved.
//
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Facebook.
//
// As with any software that integrates with the Facebook platform, your use of
// this software is subject to the Facebook Developer Principles and Policies
// [http://developers.facebook.com/policy/]. This copyright notice shall be
// included in all copies or substantial portions of the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "FBSDKWebDialogView.h"

#import "FBSDKCloseIcon.h"
#import "FBSDKError.h"
#import "FBSDKInternalUtility.h"
#import "FBSDKTypeUtility.h"

#define FBSDK_WEB_DIALOG_VIEW_BORDER_WIDTH 10.0

@interface FBSDKWebDialogView () <UIWebViewDelegate>
@end

@implementation FBSDKWebDialogView
{
  UIButton *_closeButton;
  UIActivityIndicatorView *_loadingView;
  
  #if !TARGET_OS_UIKITFORMAC
  
    UIWebView *_webView;

  #endif

}

#pragma mark - Object Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
   #if !TARGET_OS_UIKITFORMAC
  
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;

    _webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    _webView.delegate = self;
    [self addSubview:_webView];

    _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *closeImage = [[[FBSDKCloseIcon alloc] init] imageWithSize:CGSizeMake(29.0, 29.0)];
    [_closeButton setImage:closeImage forState:UIControlStateNormal];
    [_closeButton setTitleColor:[UIColor colorWithRed:167.0/255.0
                                                green:184.0/255.0
                                                 blue:216.0/255.0
                                                alpha:1.0] forState:UIControlStateNormal];
    [_closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    _closeButton.showsTouchWhenHighlighted = YES;
    [_closeButton sizeToFit];
    [self addSubview:_closeButton];
    [_closeButton addTarget:self action:@selector(_close:) forControlEvents:UIControlEventTouchUpInside];

    _loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _loadingView.color = [UIColor grayColor];
    [_webView addSubview:_loadingView];
  }
#else
  self = [super initWithFrame:frame];
  
  
#endif
  return self;
}

- (void)dealloc
{
  #if !TARGET_OS_UIKITFORMAC
  _webView.delegate = nil;
#endif
}

#pragma mark - Public Methods

- (void)loadURL:(NSURL *)URL
{
  #if !TARGET_OS_UIKITFORMAC
  
  [_loadingView startAnimating];
  [_webView loadRequest:[NSURLRequest requestWithURL:URL]];

#endif
}

- (void)stopLoading
{
   #if !TARGET_OS_UIKITFORMAC
    [_webView stopLoading];
#endif
}

#pragma mark - Layout

- (void)drawRect:(CGRect)rect
{
   #if !TARGET_OS_UIKITFORMAC
  
  
  
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSaveGState(context);
  [self.backgroundColor setFill];
  CGContextFillRect(context, self.bounds);
  [[UIColor blackColor] setStroke];
  CGContextSetLineWidth(context, 1.0 / self.layer.contentsScale);
  CGContextStrokeRect(context, _webView.frame);
  CGContextRestoreGState(context);
  [super drawRect:rect];
  
#endif
}

- (void)layoutSubviews
{
  #if !TARGET_OS_UIKITFORMAC
  
  [super layoutSubviews];

  CGRect bounds = self.bounds;
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    CGFloat horizontalInset = CGRectGetWidth(bounds) * 0.2;
    CGFloat verticalInset = CGRectGetHeight(bounds) * 0.2;
    UIEdgeInsets iPadInsets = UIEdgeInsetsMake(verticalInset, horizontalInset, verticalInset, horizontalInset);
    bounds = UIEdgeInsetsInsetRect(bounds, iPadInsets);
  }
  UIEdgeInsets webViewInsets = UIEdgeInsetsMake(FBSDK_WEB_DIALOG_VIEW_BORDER_WIDTH,
                                                FBSDK_WEB_DIALOG_VIEW_BORDER_WIDTH,
                                                FBSDK_WEB_DIALOG_VIEW_BORDER_WIDTH,
                                                FBSDK_WEB_DIALOG_VIEW_BORDER_WIDTH);
  _webView.frame = CGRectIntegral(UIEdgeInsetsInsetRect(bounds, webViewInsets));

  CGRect webViewBounds = _webView.bounds;
  _loadingView.center = CGPointMake(CGRectGetMidX(webViewBounds), CGRectGetMidY(webViewBounds));

  if (CGRectGetHeight(webViewBounds) == 0.0) {
    _closeButton.alpha = 0.0;
  } else {
    _closeButton.alpha = 1.0;
    CGRect closeButtonFrame = _closeButton.bounds;
    closeButtonFrame.origin = bounds.origin;
    _closeButton.frame = CGRectIntegral(closeButtonFrame);
  }
  
  #endif
}

#pragma mark - Actions

- (void)_close:(id)sender
{
  [_delegate webDialogViewDidCancel:self];
}

#pragma mark - UIWebViewDelegate

#if !TARGET_OS_UIKITFORMAC

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
  [_loadingView stopAnimating];

  // 102 == WebKitErrorFrameLoadInterruptedByPolicyChange
  // NSURLErrorCancelled == "Operation could not be completed", note NSURLErrorCancelled occurs when the user clicks
  // away before the page has completely loaded, if we find cases where we want this to result in dialog failure
  // (usually this just means quick-user), then we should add something more robust here to account for differences in
  // application needs
  if (!(([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) ||
        ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102))) {
    [_delegate webDialogView:self didFailWithError:error];
  }
}

- (BOOL)webView:(UIWebView *)webView
shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{
  NSURL *URL = request.URL;

  if ([URL.scheme isEqualToString:@"fbconnect"]) {
    NSMutableDictionary<NSString *, id> *parameters = [[FBSDKBasicUtility dictionaryWithQueryString:URL.query] mutableCopy];
    [parameters addEntriesFromDictionary:[FBSDKBasicUtility dictionaryWithQueryString:URL.fragment]];
    if ([URL.resourceSpecifier hasPrefix:@"//cancel"]) {
      NSInteger errorCode = [FBSDKTypeUtility integerValue:parameters[@"error_code"]];
      if (errorCode) {
        NSString *errorMessage = [FBSDKTypeUtility stringValue:parameters[@"error_msg"]];
        NSError *error = [NSError fbErrorWithCode:errorCode message:errorMessage];
        [_delegate webDialogView:self didFailWithError:error];
      } else {
        [_delegate webDialogViewDidCancel:self];
      }
    } else {
      [_delegate webDialogView:self didCompleteWithResults:parameters];
    }
    return NO;
  } else if (navigationType == UIWebViewNavigationTypeLinkClicked) {
    [[UIApplication sharedApplication] openURL:request.URL];
    return NO;
  } else {
    return YES;
  }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
  [_loadingView stopAnimating];
  [_delegate webDialogViewDidFinishLoad:self];
}


#endif

@end
