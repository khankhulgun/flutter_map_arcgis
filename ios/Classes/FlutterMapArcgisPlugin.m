#import "FlutterMapArcgisPlugin.h"
#if __has_include(<flutter_map_arcgis/flutter_map_arcgis-Swift.h>)
#import <flutter_map_arcgis/flutter_map_arcgis-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_map_arcgis-Swift.h"
#endif

@implementation FlutterMapArcgisPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterMapArcgisPlugin registerWithRegistrar:registrar];
}
@end
