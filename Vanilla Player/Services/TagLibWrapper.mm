#import "TagLibWrapper.h"

#import <fileref.h>
#import <tag.h>
#import <tstring.h>
#import <flacfile.h>
#import <wavfile.h>
#import <mp4file.h>
#import <aifffile.h>
#import <apefile.h>
#import <wavpackfile.h>
#import <mpegfile.h>
#import <id3v2tag.h>
#import <attachedpictureframe.h>
#import <mp4tag.h>
#import <mp4coverart.h>
#import <flacpicture.h>
#import <mp4item.h>

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
    
    if (f.audioProperties()) {
        TagLib::AudioProperties *properties = f.audioProperties();
        data.duration = properties->lengthInSeconds();
        data.bitrate = properties->bitrate();
        data.sampleRate = properties->sampleRate();
        data.channels = properties->channels();
        
        // Try to get bit depth for supported formats
        if (TagLib::FLAC::File *flac = dynamic_cast<TagLib::FLAC::File *>(f.file())) {
            data.bitDepth = flac->audioProperties()->bitsPerSample();
        } else if (TagLib::RIFF::WAV::File *wav = dynamic_cast<TagLib::RIFF::WAV::File *>(f.file())) {
            data.bitDepth = wav->audioProperties()->bitsPerSample();
        } else if (TagLib::RIFF::AIFF::File *aiff = dynamic_cast<TagLib::RIFF::AIFF::File *>(f.file())) {
            data.bitDepth = aiff->audioProperties()->bitsPerSample();
        } else if (TagLib::MP4::File *mp4 = dynamic_cast<TagLib::MP4::File *>(f.file())) {
            data.bitDepth = mp4->audioProperties()->bitsPerSample();
        } else if (TagLib::APE::File *ape = dynamic_cast<TagLib::APE::File *>(f.file())) {
            data.bitDepth = ape->audioProperties()->bitsPerSample();
        } else if (TagLib::WavPack::File *wv = dynamic_cast<TagLib::WavPack::File *>(f.file())) {
            data.bitDepth = wv->audioProperties()->bitsPerSample();
        }
        // Note: MP3 (MPEG), Vorbis, and Opus are lossy and do not have a fixed bit depth.
    }
    
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

+ (BOOL)writeArtwork:(nullable NSData *)artworkData toURL:(NSURL *)url error:(NSError **)error {
    if (!url) return NO;
    
    const char *path = [url.path fileSystemRepresentation];
    TagLib::FileRef f(path);
    
    if (f.isNull()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibWrapper" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Could not open file"}];
        }
        return NO;
    }
    
    TagLib::ByteVector imageData;
    if (artworkData) {
        imageData = TagLib::ByteVector((const char *)artworkData.bytes, (unsigned int)artworkData.length);
    }
    
    // 1. Handle ID3v2 (MP3, WAV, AIFF)
    if (TagLib::MPEG::File *mpegFile = dynamic_cast<TagLib::MPEG::File *>(f.file())) {
        TagLib::ID3v2::Tag *tag = mpegFile->ID3v2Tag(true);
        if (tag) {
            // Remove existing APIC frames
            TagLib::ID3v2::FrameList frames = tag->frameList("APIC");
            for (auto it = frames.begin(); it != frames.end(); ++it) {
                tag->removeFrame(*it);
            }
            
            if (artworkData) {
                TagLib::ID3v2::AttachedPictureFrame *frame = new TagLib::ID3v2::AttachedPictureFrame();
                frame->setPicture(imageData);
                frame->setType(TagLib::ID3v2::AttachedPictureFrame::FrontCover);
                // Simple mime detection
                if (artworkData.length > 4) {
                    const uint8_t *bytes = (const uint8_t *)artworkData.bytes;
                    if (bytes[0] == 0xFF && bytes[1] == 0xD8) frame->setMimeType("image/jpeg");
                    else if (bytes[0] == 0x89 && bytes[1] == 'P' && bytes[2] == 'N' && bytes[3] == 'G') frame->setMimeType("image/png");
                }
                tag->addFrame(frame);
            }
        }
    }
    // 2. Handle FLAC
    else if (TagLib::FLAC::File *flacFile = dynamic_cast<TagLib::FLAC::File *>(f.file())) {
        flacFile->removePictures();
        if (artworkData) {
            TagLib::FLAC::Picture *picture = new TagLib::FLAC::Picture();
            picture->setData(imageData);
            picture->setType(TagLib::FLAC::Picture::FrontCover);
            if (artworkData.length > 4) {
                const uint8_t *bytes = (const uint8_t *)artworkData.bytes;
                if (bytes[0] == 0xFF && bytes[1] == 0xD8) picture->setMimeType("image/jpeg");
                else if (bytes[0] == 0x89 && bytes[1] == 'P' && bytes[2] == 'N' && bytes[3] == 'G') picture->setMimeType("image/png");
            }
            flacFile->addPicture(picture);
        }
    }
    // 3. Handle MP4
    else if (TagLib::MP4::File *mp4File = dynamic_cast<TagLib::MP4::File *>(f.file())) {
        TagLib::MP4::Tag *tag = dynamic_cast<TagLib::MP4::Tag *>(mp4File->tag());
        if (tag) {
            if (artworkData) {
                TagLib::MP4::CoverArtList covers;
                TagLib::MP4::CoverArt::Format format = TagLib::MP4::CoverArt::JPEG;
                if (artworkData.length > 4) {
                    const uint8_t *bytes = (const uint8_t *)artworkData.bytes;
                    if (bytes[0] == 0x89 && bytes[1] == 'P') format = TagLib::MP4::CoverArt::PNG;
                }
                covers.append(TagLib::MP4::CoverArt(format, imageData));
                tag->setItem("covr", TagLib::MP4::Item(covers));
            } else {
                tag->removeItem("covr");
            }
        }
    }
    
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
