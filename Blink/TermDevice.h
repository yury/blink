#import <Foundation/Foundation.h>

@interface TermDevice : NSObject

@property (readonly) TermStream *stream;
// TODO: @property TermWidget *control;
@property TermController *control;

- (void)write:(NSString *)input;

@end
