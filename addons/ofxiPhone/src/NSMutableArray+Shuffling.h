// NSMutableArray+Shuffling.h
#import <Foundation/Foundation.h>

/** This category enhances NSMutableArray by providing methods to randomly
 * shuffle the elements using the Fisher-Yates algorithm.
 */
@interface NSMutableArray (Shuffling)
- (void)shuffle;
@end

@implementation NSMutableArray (Shuffling)

- (void)shuffle
{
    NSUInteger count = [self count];
    for (uint i = 0; i < count; ++i)
    {
        // Select a random element between i and end of array to swap with.
        int nElements = count - i;
        int n = arc4random_uniform(nElements) + i;
        [self exchangeObjectAtIndex:i withObjectAtIndex:n];
    }
}

@end