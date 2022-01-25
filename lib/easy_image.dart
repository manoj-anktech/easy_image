library easy_image;

import 'dart:io';

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

class CropSettings {
  const CropSettings({
    this.maxWidth,
    this.maxHeight,
    this.aspectRatio,
    this.androidUiSettings,
    this.iosUiSettings,
    this.cropStyle = CropStyle.rectangle,
    this.compressFormat = ImageCompressFormat.jpg,
    this.compressQuality = 90,
  });

  final int? maxWidth;
  final int? maxHeight;
  final CropAspectRatio? aspectRatio;
  final AndroidUiSettings? androidUiSettings;
  final IOSUiSettings? iosUiSettings;
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

class EasyImage extends StatefulWidget {
  const EasyImage({
    required this.builder,
    required this.camera,
    required this.gallery,
    required this.onPermissionError,
    this.initialUrl,
    this.removeAction,
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

  final CropSettings? cropSettings;

  final ErrorCallback? onError;

  final ValueChanged<String?>? onChanged;

  @override
  EasyImageState createState() => EasyImageState();
}

class EasyImageState extends State<EasyImage> {
  String? _initialUrl;
  File? _croppedFile;
  XFile? _file;

  String? get localUrl {
    if (kIsWeb) {
      return _file?.path;
    } else {
      return _croppedFile?.path ?? _file?.path;
    }
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

    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return SafeArea(
            child: Container(
              child: Wrap(
                children: <Widget>[
                  ListTile(
                      leading: widget.camera.leading,
                      title: widget.camera.title,
                      onTap: () {
                        _getImage(ImageSource.camera);
                        Navigator.of(context).pop();
                      }),
                  ListTile(
                    leading: widget.gallery.leading,
                    title: widget.gallery.title,
                    onTap: () {
                      _getImage(
                        ImageSource.gallery,
                      );
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
            ),
          );
        });
  }

  void _getImage(ImageSource source) async {
    final cropSettings = widget.cropSettings;

    try {
      final file = await _imagePicker.pickImage(
          source: source,
          maxWidth: kIsWeb ? cropSettings?.maxWidth?.toDouble() : null,
          maxHeight: kIsWeb ? cropSettings?.maxHeight?.toDouble() : null);

      if (file != null) {
        if (kIsWeb) {
          _setFiles(file, null);
          return;
        }

        final croppedFile = await ImageCropper.cropImage(
            sourcePath: file.path,
            aspectRatio: cropSettings?.aspectRatio,
            maxWidth: cropSettings?.maxWidth,
            maxHeight: cropSettings?.maxHeight,
            compressQuality: cropSettings?.compressQuality ?? 90,
            compressFormat:
                cropSettings?.compressFormat ?? ImageCompressFormat.jpg,
            androidUiSettings: cropSettings?.androidUiSettings,
            iosUiSettings: cropSettings?.iosUiSettings);

        _setFiles(file, croppedFile);
      }
    } on PlatformException catch (exception, stack) {
      if (exception.code == "camera_access_denied" ||
          exception.code == "photo_access_denied") {
        final isCamera = exception.code == "camera_access_denied";
        widget.onPermissionError.call(isCamera);
      } else {
        widget.onError?.call(exception, stack);
      }
    } catch (exception, stack) {
      widget.onError?.call(exception, stack);
    }
  }

  _setFiles(XFile file, File? croppedFile) {
    setState(() {
      _initialUrl = null;
      _file = _file;
      _croppedFile = croppedFile;
      widget.onChanged?.call(localUrl);
    });
  }

  _removeImage() {
    setState(() {
      _initialUrl = null;
      _file = null;
      _croppedFile = null;
      widget.onChanged?.call(localUrl);
    });
  }
}
