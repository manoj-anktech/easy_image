library easy_image;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

final _imagePicker = ImagePicker();

typedef WidgetBuilder = Widget Function(
    BuildContext context,
    String? url,
    bool isFromNetwork,
    VoidCallback? onPressed,
    );

typedef PermissionErrorCallback = void Function(bool isCamera);

typedef ErrorCallback = void Function(dynamic exception, StackTrace? stack);

typedef RemoveCallback = Future<bool> Function();

typedef LibraryCallback = Future<String?> Function();

class CropSettings {
  const CropSettings({
    this.maxWidth,
    this.maxHeight,
    this.aspectRatio,
    this.androidUiSettings,
    this.iosUiSettings,
    this.webUiSettings,
    this.cropStyle = CropStyle.rectangle,
    this.compressFormat = ImageCompressFormat.jpg,
    this.compressQuality = 90,
  });

  final int? maxWidth;
  final int? maxHeight;
  final CropAspectRatio? aspectRatio;
  final AndroidUiSettings? androidUiSettings;
  final IOSUiSettings? iosUiSettings;
  final WebUiSettings? webUiSettings;
  final CropStyle cropStyle;
  final ImageCompressFormat compressFormat;
  final int compressQuality;
}

class EasyImageListTile {
  const EasyImageListTile({
    required this.leading,
    required this.title,
  });

  final Widget leading;
  final Widget title;
}

class EasyImageRemoveAction extends EasyImageListTile {
  const EasyImageRemoveAction({
    required Widget leading,
    required Widget title,
    required this.onRemove,
  }) : super(
    leading: leading,
    title: title,
  );

  final RemoveCallback onRemove;
}

class EasyImageLibraryAction extends EasyImageListTile {
  const EasyImageLibraryAction({
    required Widget leading,
    required Widget title,
    required this.onLibraryClick,
  }) : super(
    leading: leading,
    title: title,
  );

  final LibraryCallback onLibraryClick;
}

class EasyImage extends StatefulWidget {
  const EasyImage({
    required this.builder,
    required this.camera,
    required this.gallery,
    required this.onPermissionError,
    this.initialUrl,
    this.removeAction,
    this.libraryAction,
    this.cropSettings,
    this.onError,
    this.onChanged,
    Key? key,
  }) : super(key: key);

  final WidgetBuilder builder;

  final EasyImageListTile camera;

  final EasyImageListTile gallery;

  final PermissionErrorCallback onPermissionError;

  final String? initialUrl;

  final EasyImageRemoveAction? removeAction;

  final EasyImageLibraryAction? libraryAction;

  final CropSettings? cropSettings;

  final ErrorCallback? onError;

  final ValueChanged<String?>? onChanged;

  @override
  EasyImageState createState() => EasyImageState();
}

class EasyImageState extends State<EasyImage> {
  String? _initialUrl;

  ImagePickerResult? _imagePickerResult;

  String? get localUrl {
    return _imagePickerResult?.url;
  }

  bool get isFromNetwork {
    if (kIsWeb) {
      return true;
    } else {
      return localUrl == null;
    }
  }

  String? get _url {
    return localUrl ?? _initialUrl;
  }

  @override
  void initState() {
    _initialUrl = widget.initialUrl;
    super.initState();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _url, isFromNetwork, showPicker);

  void showPicker() {
    final removeAction = widget.removeAction;

    final libraryAction = widget.libraryAction;

    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                if (libraryAction != null)
                  ListTile(
                    leading: libraryAction.leading,
                    title: libraryAction.title,
                    onTap: () async {
                      Navigator.of(context).pop();
                      final result = await libraryAction.onLibraryClick();
                      if (result != null) {
                        _setImagePickerResult(ImagePickerResult(camera: result, cropped: result),);
                      }
                    },
                  ),
                ListTile(
                  leading: widget.camera.leading,
                  title: widget.camera.title,
                  onTap: () {
                    _getImage(ImageSource.camera);
                    Navigator.of(context).pop();
                  },),
                ListTile(
                  leading: widget.gallery.leading,
                  title: widget.gallery.title,
                  onTap: () {
                    _getImage(ImageSource.gallery);
                    Navigator.of(context).pop();
                  },
                ),
                if (removeAction != null)
                  ListTile(
                    leading: removeAction.leading,
                    title: removeAction.title,
                    onTap: () async {
                      Navigator.of(context).pop();
                      final result = await removeAction.onRemove();
                      if (result) {
                        _removeImage();
                      }
                    },
                  ),
              ],
            ),
          );
        }

    );
  }

  void _getImage(ImageSource source,) async {
    final cropSettings = widget.cropSettings;

    final result = await getImage(
      source: source,
      cropSettings: cropSettings,
    );

    final error = result.error;

    if (error == null) {
      _setImagePickerResult(result);
    } else {
      final code = error.code;
      if (code == "camera_access_denied" || code == "photo_access_denied") {
        final isCamera = code == "camera_access_denied";
        widget.onPermissionError.call(isCamera);
      } else {
        widget.onError?.call(error, result.stackTrace);
      }
    }
  }

  _setImagePickerResult(ImagePickerResult result) {
    setState(() {
      _initialUrl = null;
      _imagePickerResult = result;
      widget.onChanged?.call(localUrl);
    });
  }

  _removeImage() {
    setState(() {
      _initialUrl = null;
      _imagePickerResult = null;
      widget.onChanged?.call(localUrl);
    });
  }
}

@immutable
class ImagePickerResult {
  final String? camera;
  final String? cropped;
  final dynamic error;
  final StackTrace? stackTrace;

  const ImagePickerResult({
    this.camera,
    this.cropped,
    this.error,
    this.stackTrace,
  });

  String? get url {
    return cropped ?? camera;
  }
}

Future<ImagePickerResult> getImage({
  required ImageSource source,
  CropSettings? cropSettings,
}) async {
  try {
    final file = await _imagePicker.pickImage(
      source: source,
    );

    if (file != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: cropSettings?.aspectRatio,
        maxWidth: cropSettings?.maxWidth,
        maxHeight: cropSettings?.maxHeight,
        compressQuality: cropSettings?.compressQuality ?? 90,
        compressFormat: cropSettings?.compressFormat ?? ImageCompressFormat.jpg,
        uiSettings: [
          cropSettings?.androidUiSettings,
          cropSettings?.iosUiSettings,
          cropSettings?.webUiSettings,
        ].whereNotNull().toList(),
      );

      return ImagePickerResult(camera: file.path, cropped: croppedFile?.path);
    }
  } catch (exception, stackTrace) {
    return ImagePickerResult(error: exception, stackTrace: stackTrace);
  }

  return ImagePickerResult(error: PlatformException(code: "unknown"));
}
