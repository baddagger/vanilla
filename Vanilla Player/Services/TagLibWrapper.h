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

@property (nonatomic, assign) NSInteger duration;
@property (nonatomic, assign) NSInteger bitrate;
@property (nonatomic, assign) NSInteger sampleRate;
@property (nonatomic, assign) NSInteger channels;
@property (nonatomic, assign) NSInteger bitDepth;

@end

@interface TagLibWrapper : NSObject

+ (nullable AudioTagData *)readTagsFromURL:(NSURL *)url error:(NSError **)error;
+ (BOOL)writeTags:(AudioTagData *)tags toURL:(NSURL *)url error:(NSError **)error;
+ (BOOL)writeArtwork:(nullable NSData *)artworkData toURL:(NSURL *)url error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
