import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import '../translations.i18n.dart';

ImagesDatabase imagesDatabase = ImagesDatabase();

class ImagesDatabase {
  /*
  !!! Using the wrappers so i don't have to rewrite most of the code, because of migration to cached network image
  */

  void saveImage(String url) {
    CachedNetworkImageProvider(url);
  }

  Future<PaletteGenerator> getPaletteGenerator(String url) {
    return PaletteGenerator.fromImageProvider(CachedNetworkImageProvider(url));
  }

  Future<Color> getPrimaryColor(String url) async {
    PaletteGenerator paletteGenerator = await getPaletteGenerator(url);
    return paletteGenerator.colors.first;
  }

  Future<bool> isDark(String url) async {
    PaletteGenerator paletteGenerator = await getPaletteGenerator(url);
    return paletteGenerator.colors.first.computeLuminance() > 0.5 ? false : true;
  }
}

class CachedImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final bool circular;
  final bool fullThumb;
  final bool rounded;

  const CachedImage(
      {super.key,
      required this.url,
      this.height,
      this.width,
      this.circular = false,
      this.fullThumb = false,
      this.rounded = false});

  @override
  _CachedImageState createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  @override
  Widget build(BuildContext context) {
    if (widget.rounded) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: CachedImage(
            url: widget.url,
            height: widget.height,
            width: widget.width,
            circular: false,
            rounded: false,
            fullThumb: widget.fullThumb),
      );
    }

    if (widget.circular) {
      return ClipOval(
          child: CachedImage(
        url: widget.url,
        height: widget.height,
        width: widget.width,
        circular: false,
        rounded: false,
        fullThumb: widget.fullThumb,
      ));
    }

    if (!widget.url.startsWith('http')) {
      return Image.asset(
        widget.url,
        width: widget.width,
        height: widget.height,
      );
    }

    return CachedNetworkImage(
      imageUrl: widget.url,
      width: widget.width,
      height: widget.height,
      placeholder: (context, url) {
        if (widget.fullThumb) {
          return Image.asset(
            'assets/cover.jpg',
            width: widget.width,
            height: widget.height,
          );
        }
        return Image.asset('assets/cover_thumb.jpg', width: widget.width, height: widget.height);
      },
      errorWidget: (context, url, error) =>
          Image.asset('assets/cover_thumb.jpg', width: widget.width, height: widget.height),
    );
  }
}

class ZoomableImage extends StatefulWidget {
  final String url;
  final bool rounded;
  final double? width;

  const ZoomableImage({super.key, required this.url, this.rounded = false, this.width});

  @override
  _ZoomableImageState createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> {
  BuildContext? ctx;
  PhotoViewController? controller;
  bool photoViewOpened = false;

  @override
  void initState() {
    super.initState();
    controller = PhotoViewController()..outputStateStream.listen(listener);
  }

  // Listener of PhotoView scale changes. Used for closing PhotoView by pinch-in
  void listener(PhotoViewControllerValue value) {
    if (value.scale! < 0.16 && photoViewOpened) {
      Navigator.pop(ctx!);
      photoViewOpened = false; // to avoid multiple pop() when picture are being scaled out too slowly
    }
  }

  @override
  Widget build(BuildContext context) {
    ctx = context;
    return TextButton(
        child: Semantics(
          label: 'Album art'.i18n,
          child: CachedImage(
            url: widget.url,
            rounded: widget.rounded,
            width: widget.width,
            fullThumb: true,
          ),
        ),
        onPressed: () {
          Navigator.of(context).push(PageRouteBuilder(
              opaque: false, // transparent background
              pageBuilder: (context, a, b) {
                photoViewOpened = true;
                return PhotoView(
                    imageProvider: CachedNetworkImageProvider(widget.url),
                    maxScale: 8.0,
                    minScale: 0.2,
                    controller: controller,
                    backgroundDecoration: const BoxDecoration(color: Color.fromARGB(0x90, 0, 0, 0)));
              }));
        });
  }
}
