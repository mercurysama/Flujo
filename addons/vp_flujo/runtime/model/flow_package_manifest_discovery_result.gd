@tool
class_name FlowPackageManifestDiscoveryResult
extends FlowValidationResult

## Fresh read-only snapshot produced by one manifest discovery pass.
var manifests: Array[FlowPackageManifest] = []
