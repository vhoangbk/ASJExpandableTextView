// ASJExpandableTextView.m
//
// Copyright (c) 2015 Sudeep Jaiswal
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "ASJExpandableTextView.h"

@interface ASJExpandableTextView () {
  UILabel *placeholderLabel;
  NSUInteger currentLine;
  CGFloat previousContentHeight, defaultTextViewHeight, defaultContentHeight;
  BOOL isPlaceholderVisible, areLayoutDefaultsSet;
}

@property (nonatomic) CGFloat heightOfOneLine;
@property (nonatomic) CGFloat currentContentHeight;
@property (nonatomic) CGFloat currentTextViewHeight;
@property (nonatomic) BOOL shouldShowPlaceholder;
@property (nonatomic) NSLayoutConstraint *heightConstraint;

- (void)initialisations;
- (void)setDefaults;
- (void)executeDefaultFontHack;
- (void)setPlaceholderLabel;
- (void)listenForNotifications;
- (void)handleTextChange;
- (void)handleExpansion;
- (void)handleNextLine;
- (void)handlePreviousLine;
- (void)animateConstraintToHeight:(CGFloat)height;
- (void)animateFrameToHeight:(CGFloat)height;
- (void)scrollToBottom;

@end

@implementation ASJExpandableTextView

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer
{
  self = [super initWithFrame:frame textContainer:textContainer];
  if (self) {
    [self initialisations];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
  self = [super initWithCoder:coder];
  if (self) {
    [self initialisations];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  if (!areLayoutDefaultsSet && _hasDynamicHeight) {
    [self setLayoutDefaults];
    [self setPlaceholderLabel];
    areLayoutDefaultsSet = YES;
  }
}

- (void)setLayoutDefaults {
  currentLine = 1;
  defaultContentHeight = self.contentSize.height;
  defaultTextViewHeight = self.frame.size.height;
  previousContentHeight = _currentContentHeight = defaultContentHeight;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Set up

- (void)initialisations {
  [self setDefaults];
  [self executeDefaultFontHack];
  [self listenForNotifications];
}

- (void)setDefaults {
  _hasDynamicHeight = NO;
  _maximumLineCount = 4;
  self.shouldShowPlaceholder = NO;
  self.textContainerInset = UIEdgeInsetsMake(8, 6, 8, 8);
}

- (void)executeDefaultFontHack {
  /**
   Unless text is set, self.font is nil, it doesn't seem to initialise when the text view is created.
   */
  self.text = @"weirdness";
  self.text = nil;
}

- (void)setPlaceholderLabel {
  CGFloat x = 10;
  CGFloat y = 8;
  CGFloat width = self.frame.size.width - 20;
  CGFloat height = 0;
  placeholderLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y, width, height)];
  placeholderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  placeholderLabel.lineBreakMode = NSLineBreakByWordWrapping;
  placeholderLabel.numberOfLines = 0;
  placeholderLabel.text = self.placeholder;
  placeholderLabel.textColor = self.textColor;
  placeholderLabel.font = self.font;
  placeholderLabel.alpha = 0.6;
  placeholderLabel.backgroundColor = [UIColor clearColor];
  [self addSubview:placeholderLabel];
  [placeholderLabel sizeToFit];
}


#pragma mark - Text change

- (void)listenForNotifications {
  
  [[NSNotificationCenter defaultCenter]
   addObserverForName:UITextViewTextDidBeginEditingNotification
   object:self queue:[NSOperationQueue mainQueue]
   usingBlock:^(NSNotification *note) {
     [self handleTextChange];
   }];
  
  [[NSNotificationCenter defaultCenter]
   addObserverForName:UITextViewTextDidChangeNotification
   object:self queue:[NSOperationQueue mainQueue]
   usingBlock:^(NSNotification *note) {
     [self handleTextChange];
     if (_hasDynamicHeight) {
       [self handleExpansion];
     }
   }];
}

- (void)handleTextChange {
  if (self.text.length) {
    self.shouldShowPlaceholder = NO;
    return;
  }
  if (!isPlaceholderVisible) {
    self.shouldShowPlaceholder = YES;;
  }
}

- (void)handleExpansion {
  BOOL isOnCurrentLine = (self.currentContentHeight == previousContentHeight) ? YES : NO;
  if (isOnCurrentLine) {
    return;
  }
  BOOL isOnNextLine = (self.currentContentHeight > previousContentHeight) ? YES : NO;
  previousContentHeight = self.currentContentHeight;
  if (isOnNextLine) {
    [self handleNextLine];
    return;
  }
  [self handlePreviousLine];
}

- (CGFloat)currentContentHeight {
  return self.contentSize.height;
}


#pragma mark - Next and previous lines

- (void)handleNextLine {
  currentLine++;
  if (currentLine > _maximumLineCount) {
    return;
  }
  if (self.currentContentHeight <= self.currentTextViewHeight) {
    return;
  }
  CGFloat newHeight = 0.0;
  BOOL isHeightConstraintAvailable = self.heightConstraint ? YES : NO;
  if (isHeightConstraintAvailable) {
    newHeight = self.heightConstraint.constant + round(self.heightOfOneLine);
    [self animateConstraintToHeight:newHeight];
  }
  else {
    newHeight = self.currentTextViewHeight + round(self.heightOfOneLine);
    [self animateFrameToHeight:newHeight];
  }
}

- (void)handlePreviousLine {
  currentLine--;
  if (self.currentContentHeight >= self.currentTextViewHeight) {
    return;
  }
  if (self.currentTextViewHeight <= defaultTextViewHeight) {
    return;
  }
  CGFloat newHeight = 0.0;
  BOOL isHeightConstraintAvailable = self.heightConstraint ? YES : NO;
  if (isHeightConstraintAvailable) {
    newHeight = self.heightConstraint.constant - round(self.heightOfOneLine);
    [self animateConstraintToHeight:newHeight];
  }
  else {
    newHeight = self.currentTextViewHeight - round(self.heightOfOneLine);
    [self animateFrameToHeight:newHeight];
  }
}

- (CGFloat)heightOfOneLine {
  return self.font.lineHeight;
}

- (void)animateConstraintToHeight:(CGFloat)height {
  [self.superview layoutIfNeeded];
  self.heightConstraint.constant = height;
  [UIView animateWithDuration:0.30
                        delay:0.0
                      options:UIViewAnimationOptionLayoutSubviews
                   animations:^{
                     [self scrollToBottom];
                     [self.superview layoutIfNeeded];
                   } completion:nil];
}

- (void)animateFrameToHeight:(CGFloat)height {
  [UIView animateWithDuration:0.30
                        delay:0.0
                      options:UIViewAnimationOptionLayoutSubviews
                   animations:^{
                     CGFloat x = self.frame.origin.x;
                     CGFloat y = self.frame.origin.y;
                     CGFloat width = self.frame.size.width;
                     self.frame = CGRectMake(x, y, width, height);
                   } completion:nil];
}

- (NSLayoutConstraint *)heightConstraint {
  for (NSLayoutConstraint *constraint in self.constraints) {
    if (constraint.firstAttribute == NSLayoutAttributeHeight) {
      return constraint;
    }
  }
  return nil;
}

- (CGFloat)currentTextViewHeight {
  return self.frame.size.height;
}

- (void)scrollToBottom {
  NSRange range = NSMakeRange(self.text.length - 1, 1);
  [self scrollRangeToVisible:range];
}


#pragma mark - Property setter overrides

- (void)setPlaceholder:(NSString *)placeholder {
  _placeholder = placeholder;
  placeholderLabel.text = _placeholder;
  [placeholderLabel sizeToFit];
  self.shouldShowPlaceholder = YES;
}

- (void)setText:(NSString *)text {
  [super setText:text];
  if (text && text.length) {
    self.shouldShowPlaceholder = NO;
    return;
  }
  self.shouldShowPlaceholder = YES;
}

- (void)setShouldShowPlaceholder:(BOOL)shouldShowPlaceholder {
  _shouldShowPlaceholder = shouldShowPlaceholder;
  if (_shouldShowPlaceholder) {
    placeholderLabel.alpha = 0.5;
    isPlaceholderVisible = YES;
    return;
  }
  placeholderLabel.alpha = 0.0;
  isPlaceholderVisible = NO;
}

@end