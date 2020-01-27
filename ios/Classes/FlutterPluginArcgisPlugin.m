#import "FlutterPluginArcgisPlugin.h"
#if __has_include(<flutter_plugin_arcgis/flutter_plugin_arcgis-Swift.h>)
#import <flutter_plugin_arcgis/flutter_plugin_arcgis-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_plugin_arcgis-Swift.h"
#endif

@implementation FlutterPluginArcgisPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterPluginArcgisPlugin registerWithRegistrar:registrar];
}
@end
