#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioTagData : NSObject

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *artist;
@property (nonatomic, strong) NSString *album;
@property (nonatomic, strong) NSString *trackNumber;
@property (nonatomic, strong) NSString *year;
@property (nonatomic, strong) NSString *genre;
@property (nonatomic, strong) NSString *comment;

@end

@interface TagLibWrapper : NSObject

+ (nullable AudioTagData *)readTagsFromURL:(NSURL *)url error:(NSError **)error;
+ (BOOL)writeTags:(AudioTagData *)tags toURL:(NSURL *)url error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
