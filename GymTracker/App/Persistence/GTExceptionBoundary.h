#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Executes one synchronous operation inside an Objective-C exception frame.
///
/// Swift errors should still be caught by Swift inside the operation. This
/// boundary exists only for Objective-C framework exceptions, which Swift's
/// `do`/`catch` cannot intercept.
@interface GTExceptionBoundary : NSObject

+ (BOOL)performOperation:(NS_NOESCAPE void (^)(void))operation
          caughtException:(NSException * _Nullable * _Nullable)caughtException;

@end

NS_ASSUME_NONNULL_END
