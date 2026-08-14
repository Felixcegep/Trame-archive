#import "GTExceptionBoundary.h"

@implementation GTExceptionBoundary

+ (BOOL)performOperation:(NS_NOESCAPE void (^)(void))operation
          caughtException:(NSException * _Nullable * _Nullable)caughtException {
    @try {
        operation();
        return YES;
    } @catch (NSException *exception) {
        if (caughtException != NULL) {
            *caughtException = exception;
        }
        return NO;
    }
}

@end
