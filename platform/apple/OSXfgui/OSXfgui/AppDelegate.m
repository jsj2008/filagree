#import "AppDelegate.h"
#include "interpret.h"


@implementation AppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
//  struct byte_array *filename = byte_array_from_string("sync_client.fg");
    struct byte_array *filename = byte_array_from_string("im_client.fg");
    struct byte_array *args     = byte_array_from_string("id='osx'");
    interpret_file(filename, args);
}

@end
