import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:download/download.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_wasm/ffmpeg_wasm.dart';
import 'package:file/src/backends/memory/memory_file.dart';
import 'package:file/src/backends/memory/memory_file_system.dart';
import 'package:file/src/backends/memory/node.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:run_permission_helper/android_permission_manifest.dart';
import 'package:run_permission_helper/run_permission_helper.dart';
import 'package:universal_platform/universal_platform.dart';

import '../models/night_one_model.dart';

class NightOnePage extends StatefulWidget {
  const NightOnePage({Key? key}) : super(key: key);

  @override
  State<NightOnePage> createState() => _NightOnePageState();
}

class _NightOnePageState extends State<NightOnePage> {
  final TextEditingController _m3u8UrlEditingController =
      TextEditingController();
  final TextEditingController _titleEditingController = TextEditingController();
  final TextEditingController _fileFormatEditingController =
      TextEditingController();
  final MemoryFileSystem memoryFileSystem = MemoryFileSystem();

  final Color fillColor = const Color(0xff2C3040);
  late FFmpeg ffmpeg;

  List<String?> mediatsList = [];
  List<double> progressValues = [];
  Directory? dir;
  double convertProgress = 0;
  int tsListLength = 1;

  List<NightOneModel> downloadList = [
    /*NightOneModel(
        title: '测试',
        videoUrl:
        'http://1257120875.vod2.myqcloud.com/0ef121cdvodtransgzp1257120875/3055695e5285890780828799271/v.f230.m3u8'),*/
  ];

  downloadVideo(List<NightOneModel> list) async {
    for (var element in list) {
      if (UniversalPlatform.isWeb) {
        await convertM3u8UrlToMp4(element.videoUrl, element.title);
      } else {
        await downM3u8File(element.videoUrl, element.title);
      }
    }
    if (!UniversalPlatform.isWeb) {
      deleteTempDirectory(dir!);
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (UniversalPlatform.isAndroid) {
        var result = await RunPermissionHelperPlugin.requestRunPermission(
          [
            AndroidPermission.WRITE_EXTERNAL_STORAGE,
          ],
        );
        if (result?.isGranted ?? false) {
          dir = await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory();
        } else {
          dir = await getApplicationDocumentsDirectory();
        }
      } else if (!UniversalPlatform.isWeb) {
        dir = await getApplicationDocumentsDirectory();
      } else {
        // Note: CreateFFmpegParam is optional and and corePath is also optional
        // ffmpeg = createFFmpeg(CreateFFmpegParam(log: true, corePath: 'https://unpkg.com/@ffmpeg/core@0.11.0/dist/ffmpeg-core.js'));
        final url = Uri.base.resolve('ffmpeg/ffmpeg-core.js').toString();
        ffmpeg = createFFmpeg(CreateFFmpegParam(log: true, corePath: url));
        ffmpeg.setLogger((LoggerParam logger) {
          if (logger.type == 'fferr') {
            final match = regex.firstMatch(logger.message);

            if (match != null) {
              // indicates the number of frames that have been processed so far.
              final frame = match.group(1);
              // is the current frame rate
              final fps = match.group(2);
              // stands for quality 0.0 indicating lossless compression, other values indicating that there is some lossy compression happening
              final q = match.group(3);
              // indicates the size of the output file so far
              final size = match.group(4);
              // is the time that has elapsed since the beginning of the conversion
              final time = match.group(5);
              // is the current output bitrate
              final bitrate = match.group(6);
              // for instance: 'kbits/s'
              final bitrateUnit = match.group(7);
              // is the speed at which the conversion is happening, relative to real-time
              final speed = match.group(8);

              print(
                  'frame: $frame, fps: $fps, q: $q, size: $size, time: $time, bitrate: $bitrate$bitrateUnit, speed: $speed');
            }
          }
        });
        ffmpeg.setProgress((ProgressParam progress) {
          convertProgress = progress.ratio;
          currentState = "转换进度 ${convertProgress * 100}%";
          setState(() {});
        });
        if (!ffmpeg.isLoaded()) {
          print('ffmpeg loading...');
          await ffmpeg.load();
        }
      }
      setState(() {});
    });
    _fileFormatEditingController.text = "mp4";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1E202b),
      body: Container(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      videoUrlWidget,
                      const SizedBox(
                        height: 8,
                      ),
                      videoTitleWidget,
                      const SizedBox(
                        height: 8,
                      ),
                      fileFormatWidget,
                    ],
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                TextButton(
                  onPressed: () {
                    if (_m3u8UrlEditingController.text.isNotEmpty &&
                        _titleEditingController.text.isNotEmpty) {
                      downloadVideo(downloadList
                        ..add(
                          NightOneModel(
                              title: _titleEditingController.text,
                              videoUrl: _m3u8UrlEditingController.text),
                        ));
                    }
                  },
                  child: Container(
                    color: fillColor,
                    width: 70,
                    height: 70,
                    child: Center(
                        child: Text(
                      UniversalPlatform.isWeb ? "转换" : '下载',
                      style: const TextStyle(color: Colors.white),
                    )),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 8,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: UniversalPlatform.isWeb
                    ? [
                        const SizedBox(
                          height: 8,
                        ),
                        Row(
                          children: [
                            const Text(
                              "当前进度：",
                              style: TextStyle(color: Colors.white),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: LinearProgressIndicator(
                                minHeight: 1,
                                backgroundColor: Colors.green,
                                color: Colors.red,
                                value: 1 - mediatsList.length / tsListLength,
                              ),
                            )
                          ],
                        ),
                        Text(
                          "当前状态：$currentState",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ]
                    : [
                        const SizedBox(
                          height: 8,
                        ),
                        Text(
                          "正在下载：${mediatsList.length}",
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          "正在下载：${mediatsList.length}",
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          "输出路径：${dir?.path}",
                          style: const TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: dir?.path ?? ""));
                          },
                          child: Container(
                            color: fillColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: const Center(
                              child: Text(
                                "复制路径",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        Expanded(child: tsFileDownloadListWidget()),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //m3u8文件路径 Widget
  Widget get m3u8FilePathWidget {
    return Row(
      children: [
        const Text(
          'm3u8文件路径:',
          style: TextStyle(color: Colors.white),
        ),
        const SizedBox(
          width: 20,
        ),
        Expanded(
          child: TextField(
            decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: InputBorder.none,
                filled: true,
                isCollapsed: true,
                fillColor: fillColor),
            controller: _m3u8UrlEditingController,
            maxLines: 1,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }

  //视频地址 Widget
  Widget get videoUrlWidget {
    return Row(
      children: [
        const Text(
          '链接地址:',
          style: TextStyle(color: Colors.white),
        ),
        const SizedBox(
          width: 20,
        ),
        Expanded(
          child: TextField(
            decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: InputBorder.none,
                filled: true,
                isCollapsed: true,
                fillColor: fillColor),
            controller: _m3u8UrlEditingController,
            maxLines: 1,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }

  //视频标题 Widget
  Widget get videoTitleWidget {
    return Row(
      children: [
        const Text(
          '视频标题:',
          style: TextStyle(color: Colors.white),
        ),
        const SizedBox(
          width: 20,
        ),
        Expanded(
          child: TextField(
            decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: InputBorder.none,
                filled: true,
                isCollapsed: true,
                fillColor: fillColor),
            controller: _titleEditingController,
            maxLines: 1,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
      ],
    );
  }

  //文件格式 Widget
  Widget get fileFormatWidget {
    return Row(
      children: [
        const Text(
          '输出格式:',
          style: TextStyle(color: Colors.white),
        ),
        const SizedBox(
          width: 20,
        ),
        Expanded(
          child: TextField(
            decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: InputBorder.none,
                filled: true,
                isCollapsed: true,
                fillColor: fillColor),
            controller: _fileFormatEditingController,
            maxLines: 1,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
      ],
    );
  }

  //下载任务队列组件
  Widget downloadListWidget(List<NightOneModel> downloadList) {
    TextStyle textStyle = const TextStyle(
      fontSize: 12,
      color: Colors.white,
    );
    return Container(
      color: fillColor,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: ListView.separated(
                separatorBuilder: (context, index) {
                  return const Divider(
                    color: Colors.white,
                  );
                },
                itemCount: downloadList.length,
                itemBuilder: (_, index) {
                  NightOneModel nightOneModel = downloadList[index];
                  return SizedBox(
                    height: 24,
                    child: Center(
                      child: Text(
                        nightOneModel.title,
                        style: textStyle,
                        maxLines: 1,
                      ),
                    ),
                  );
                }),
          ),
          const VerticalDivider(
            color: Colors.white,
          ),
          Expanded(
            flex: 1,
            child: ListView.separated(
                separatorBuilder: (context, index) {
                  return const Divider(
                    color: Colors.white,
                  );
                },
                itemCount: downloadList.length,
                itemBuilder: (_, index) {
                  NightOneModel nightOneModel = downloadList[index];
                  return SizedBox(
                    height: 24,
                    child: Center(
                      child: Text(
                        nightOneModel.videoUrl,
                        style: textStyle,
                        maxLines: 1,
                      ),
                    ),
                  );
                }),
          )
        ],
      ),
    );
  }

  //ts文件下载队列
  Widget tsFileDownloadListWidget() {
    return Container(
      color: fillColor,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        separatorBuilder: (context, index) {
          return const Divider(
            color: Colors.white,
          );
        },
        itemCount: mediatsList.length,
        itemBuilder: (_, index) {
          String? url = mediatsList[index];
          double progress = progressValues[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  url ?? "",
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                  maxLines: 2,
                ),
                const SizedBox(
                  height: 4,
                ),
                LinearProgressIndicator(
                  minHeight: 1,
                  backgroundColor: Colors.green,
                  color: Colors.red,
                  value: progress,
                )
              ],
            ),
          );
        },
      ),
    );
  }

  String currentState = "";
  static final regex = RegExp(
    r'frame\s*=\s*(\d+)\s+fps\s*=\s*(\d+(?:\.\d+)?)\s+q\s*=\s*([\d.-]+)\s+L?size\s*=\s*(\d+)\w*\s+time\s*=\s*([\d:\.]+)\s+bitrate\s*=\s*([\d.]+)\s*(\w+)/s\s+speed\s*=\s*([\d.]+)x',
  );

  Future convertToMp4(String videoUrl, String title) async {
    print('LiuShuai: convertToMp4');
    final Dio dio = Dio();
    // String host = videoUrl.substring(0, videoUrl.lastIndexOf('/'));
    setState(() {
      currentState = "加载m3u8...";
    });
    Response<String> response = await dio.get<String>(videoUrl);
    if (response.statusCode == 200) {
      final String outputPath = "/$title.${_fileFormatEditingController.text}";
      MemoryFileSystem memoryFileSystem = MemoryFileSystem();
      MemoryFile memoryFile =
          MemoryFile(memoryFileSystem as NodeBasedFileSystem, outputPath);
    }
  }

  Future convertM3u8UrlToMp4(String videoUrl, String title) async {
    final Dio dio = Dio();
    // String host = videoUrl.substring(0, videoUrl.lastIndexOf('/'));
    setState(() {
      currentState = "加载m3u8...";
    });
    Response<String> response = await dio.get<String>(
      videoUrl,
      /*onReceiveProgress: (int count, int total) {
        setState(() {
          currentState = "加载m3u8...";
        });
      },*/
    );
    if (response.statusCode == 200) {
      List<MemoryFile> tempFile = [];
      try {
        final String m3u8FileName = "$title.m3u8";
        final List<int> codeUnits = response.data!.codeUnits;
        // final ByteBuffer buffer = Uint8List.fromList(codeUnits).buffer;
        MemoryFile m3u8File =
            MemoryFile(memoryFileSystem as NodeBasedFileSystem, m3u8FileName);
        if (!m3u8File.existsSync()) {
          m3u8File.create();
        }
        tempFile.add(m3u8File);
        m3u8File.writeAsBytes(codeUnits);
        ffmpeg.writeFile(m3u8FileName, m3u8File.readAsBytesSync());
        String host = videoUrl.substring(0, videoUrl.lastIndexOf('/'));
        HlsPlaylist? playList = await HlsPlaylistParser.create()
            .parse(Uri.parse(videoUrl), await m3u8File.readAsLines());
        if (playList is HlsMasterPlaylist) {
          return;
        } else if (playList is HlsMediaPlaylist) {
          var mediaPlaylistUrls =
              playList.segments.map((it) => it.url).toList();
          mediatsList = playList.segments.map((it) => it.url).toList();
          progressValues = List.filled(mediaPlaylistUrls.length, 0.0);
          tsListLength = mediatsList.length;
          for (var value in mediaPlaylistUrls) {
            String tsUrl = '$host/${value!.split('/').last}';
            int valueIndex = mediatsList.indexOf(value);
            Response<String> response = await dio.get<String>(tsUrl,
                onReceiveProgress: (int count, int total) {
              progressValues[valueIndex] = count / total;
              setState(() {});
            });
            if (response.statusCode == 200) {
              value.split('/').last;
              final String tsPath = value.split('/').last;
              MemoryFile tsFile =
                  MemoryFile(memoryFileSystem as NodeBasedFileSystem, tsPath);
              if (!tsFile.existsSync()) {
                tsFile.create();
              }
              tempFile.add(tsFile);
              tsFile.writeAsBytes(response.data!.codeUnits);
            } else {
              setState(() {
                currentState = "加载失败";
              });
              throw "加载失败";
            }
            mediatsList.removeAt(valueIndex);
          }
        }

        setState(() {
          currentState = "开始转换";
        });
        final String outputName = "$title.${_fileFormatEditingController.text}";
        MemoryFile outputFile =
            MemoryFile(memoryFileSystem as NodeBasedFileSystem, m3u8FileName);
        if (!outputFile.existsSync()) {
          outputFile.create();
        }
        tempFile.add(outputFile);
        /*String cmd =
            'ffmpeg -i "$videoUrl" -c copy -bsf:a aac_adtstoasc "$outputName"';*/
        String cmd = '-allowed_extensions ALL -i $m3u8FileName "$outputName"';
        /*String cmd =
            'ffmpeg -i "$videoUrl" -bsf:a aac_adtstoasc -vcodec copy -c copy $outputPath';*/
        await ffmpeg.runCommand(cmd);
        setState(() {
          currentState = "转换完成";
        });
        download(Stream.fromIterable(outputFile.readAsBytesSync()), outputName);
      } finally {
        ffmpeg.exit();
        setState(() {
          currentState = "";
        });
        if (tempFile.isNotEmpty) {
          for (var file in tempFile) {
            if(file.existsSync()){
              await file.delete();
            }
          }
        }
      }
    }
  }

  //1.下载.m3u8文件
  Future downM3u8File(String videoUrl, String videoTitle) async {
    final Dio dio = Dio();
    final String fileName = "$videoTitle.m3u8";
    String videoPath = "${dir?.path}/temp/$fileName";
    print('LiuShuai: videoPath = $videoPath');
    var response = await dio.download(videoUrl, videoPath);
    if (response.statusCode == 200) {
      return parserM3u8File(dir!, videoUrl, videoPath, videoTitle);
    }
  }

  //2.解析m3u8文件
  Future parserM3u8File(Directory dir, String viderUrl, String videoPath,
      String videoTitle) async {
    String host = viderUrl.substring(0, viderUrl.lastIndexOf('/'));
    HlsPlaylist? playList = await HlsPlaylistParser.create()
        .parse(Uri.parse(viderUrl), await File(videoPath).readAsLines());
    if (playList is HlsMasterPlaylist) {
      return;
    } else if (playList is HlsMediaPlaylist) {
      var mediaPlaylistUrls = playList.segments.map((it) => it.url).toList();
      mediatsList = playList.segments.map((it) => it.url).toList();
      tsListLength = mediatsList.length;
      progressValues = List.filled(mediaPlaylistUrls.length, 0.0);
      for (var value in mediaPlaylistUrls) {
        String tsUrl = '$host/${value!.split('/').last}';
        File file = File('${dir.path}/temp/${value.split('/').last}');
        if (!file.existsSync()) {
          //3.创建每个片段文件
          file.create();
        }
        // 4.下载每个片段文件
        int valueIndex = mediatsList.indexOf(value);
        await Dio().download(tsUrl, file.path,
            onReceiveProgress: (int count, int total) {
          progressValues[valueIndex] = count / total;
          setState(() {});
        });
        mediatsList.removeAt(valueIndex);
      }
      String outPath =
          "${dir.path}/$videoTitle.${_fileFormatEditingController.text}";
      print('LiuShuai: 输出路径: $outPath');
      String cmd =
          '-allowed_extensions ALL -i ${dir.path}/temp/$videoTitle.m3u8 "$outPath"';
      // FFmpegKit
      await FFmpegKit.executeAsync(cmd);
    }
  }

  ///4.删除临时文件
  deleteTempDirectory(Directory dir) {
    Directory directory = Directory('${dir.path}/temp');
    directory.delete(recursive: true);
  }
}
