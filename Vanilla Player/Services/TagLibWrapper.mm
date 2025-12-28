#import "TagLibWrapper.h"

#import <fileref.h>
#import <tag.h>
#import <tstring.h>

@implementation AudioTagData
@end

@implementation TagLibWrapper

+ (nullable AudioTagData *)readTagsFromURL:(NSURL *)url error:(NSError **)error {
    if (!url) return nil;
    
    // Convert NSURL to file path string for TagLib
    const char *path = [url.path fileSystemRepresentation];
    
    // TagLib::FileRef conversion
    TagLib::FileRef f(path);
    
    if (f.isNull() || !f.tag()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibWrapper" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Could not open file or no tag found"}];
        }
        return nil;
    }
    
    TagLib::Tag *tag = f.tag();
    
    AudioTagData *data = [[AudioTagData alloc] init];
    data.title = [self stringFromTagString:tag->title()];
    data.artist = [self stringFromTagString:tag->artist()];
    data.album = [self stringFromTagString:tag->album()];
    
    data.trackNumber = tag->track() > 0 ? [NSString stringWithFormat:@"%d", tag->track()] : @"";
    data.year = tag->year() > 0 ? [NSString stringWithFormat:@"%d", tag->year()] : @"";
    
    data.genre = [self stringFromTagString:tag->genre()];
    data.comment = [self stringFromTagString:tag->comment()];
    
    return data;
}

+ (BOOL)writeTags:(AudioTagData *)data toURL:(NSURL *)url error:(NSError **)error {
    if (!url || !data) return NO;
    
    const char *path = [url.path fileSystemRepresentation];
    TagLib::FileRef f(path);
    
    if (f.isNull() || !f.tag()) {
         if (error) {
             *error = [NSError errorWithDomain:@"TagLibWrapper" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Could not open file for writing"}];
         }
         return NO;
    }
    
    TagLib::Tag *tag = f.tag();
    
    tag->setTitle([self tagStringFromString:data.title]);
    tag->setArtist([self tagStringFromString:data.artist]);
    tag->setAlbum([self tagStringFromString:data.album]);
    
    tag->setTrack([data.trackNumber intValue]);
    tag->setYear([data.year intValue]);
    
    tag->setGenre([self tagStringFromString:data.genre]);
    tag->setComment([self tagStringFromString:data.comment]);
    
    if (f.save()) {
        return YES;
    } else {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibWrapper" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Failed to save file"}];
        }
        return NO;
    }
}

// Helpers
+ (NSString *)stringFromTagString:(TagLib::String)s {
    if (s.isEmpty()) return @"";
    // Convert using UTF8. TagLib::String::toCString(true) returns UTF8 char*
    return [NSString stringWithUTF8String:s.toCString(true)];
}

+ (TagLib::String)tagStringFromString:(NSString *)s {
    if (!s || s.length == 0) return TagLib::String();
    // Construct TagLib::String from UTF8 C-string
    return TagLib::String([s UTF8String], TagLib::String::UTF8);
}

@end
