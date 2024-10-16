import 'package:flutter/material.dart' show Colors, Icons, TextField;
import 'package:flutter/painting.dart'
    show EdgeInsets, TextAlign, TextBaseline, TextScaler, TextStyle;
import 'package:flutter/widgets.dart'
    show
        Actions,
        AspectRatio,
        BoxConstraints,
        BuildContext,
        CallbackAction,
        Center,
        Column,
        ConstrainedBox,
        Container,
        CrossAxisAlignment,
        Expanded,
        FocusNode,
        FutureBuilder,
        Image,
        IntrinsicHeight,
        MainAxisAlignment,
        Padding,
        Row,
        SizedBox,
        Stack,
        State,
        StatefulWidget,
        Text,
        TextEditingController,
        TextSelection,
        Widget;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:goals_core/model.dart' show Goal, GoalPath;
import 'package:goals_core/sync.dart'
    show
        ArchiveNoteLogEntry,
        GoalDelta,
        NoteLogEntry,
        ParentContextCommentEntry,
        SetSummaryEntry,
        TextGoalLogEntry;
import 'package:goals_core/util.dart' show formatDate, formatTime;
import 'package:goals_web/app_context.dart' show AppContext;
import 'package:goals_web/common/audio_player_widget.dart';
import 'package:goals_web/common/constants.dart';
import 'package:goals_web/goal_viewer/goal_breadcrumb.dart';
import 'package:goals_web/intents.dart';
import 'package:goals_web/styles.dart';
import 'package:goals_web/widgets/gg_icon_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';

class NoteCard extends StatefulWidget {
  final GoalPath path;
  final Map<String, Goal> goalMap;
  final TextGoalLogEntry textEntry;
  final Function() onRefresh;
  final bool isChildGoal;
  final bool showDate;
  final bool showTime;
  const NoteCard({
    super.key,
    required this.path,
    required this.goalMap,
    required this.textEntry,
    required this.onRefresh,
    required this.isChildGoal,
    this.showDate = false,
    this.showTime = true,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  late TextEditingController _textController =
      TextEditingController(text: widget.textEntry.text);
  bool _editing = false;
  final _focusNode = FocusNode();
  late DropzoneViewController _dropzoneController;
  bool _dropify = false;
  Map<String, VideoPlayerController> _videoControllers = {};
  Map<String, String> _downloadUrls = {};
  Map<String, AudioPlayer> _audioPlayers = {};

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  @override
  initState() {
    super.initState();
    this._focusNode.addListener(this._focusListener);
  }

  _focusListener() {
    if (this._focusNode.hasFocus) {
      return;
    }
    if (widget.textEntry.text != null &&
        _textController.text != widget.textEntry.text) {
      _saveNote();
    }
    setState(() {
      _editing = false;
    });
  }

  _saveNote() {
    _textController.selection =
        TextSelection(baseOffset: 0, extentOffset: _textController.text.length);

    switch (widget.textEntry) {
      case NoteLogEntry():
        AppContext.of(context).syncClient.modifyGoal(GoalDelta(
            id: widget.path.goalId,
            logEntry: NoteLogEntry(
                id: widget.textEntry.id,
                creationTime: DateTime.now(),
                text: _textController.text)));
        break;
      case SetSummaryEntry():
        AppContext.of(context).syncClient.modifyGoal(GoalDelta(
            id: widget.path.goalId,
            logEntry: SetSummaryEntry(
                id: Uuid().v4(),
                creationTime: DateTime.now(),
                text: _textController.text)));
        break;
      case ParentContextCommentEntry entry:
        AppContext.of(context).syncClient.modifyGoal(GoalDelta(
            id: widget.path.goalId,
            logEntry: ParentContextCommentEntry(
                id: widget.textEntry.id,
                creationTime: DateTime.now(),
                parentId: entry.parentId,
                text: _textController.text)));
        break;
      default:
        throw Exception("Unknown text entry type: ${widget.textEntry}");
    }

    setState(() {
      _editing = false;
    });
  }

  @override
  didUpdateWidget(NoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.textEntry.text;
    if (text != null && text != oldWidget.textEntry.text) {
      _textController.text = text;
    }
  }

  _discardEdit() {
    final text = widget.textEntry.text;
    if (text != null) {
      _textController.text = text;
    }
    setState(() {
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (this.widget.textEntry is NoteLogEntry)
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: uiUnit(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (this.widget.showDate)
                        Text(
                            '${formatDate(this.widget.textEntry.creationTime)} '),
                      if (this.widget.showTime)
                        Text(formatTime(widget.textEntry.creationTime)),
                      if (widget.isChildGoal) ...[
                        Text(" - "),
                        Breadcrumb(path: widget.path, goalMap: widget.goalMap),
                        SizedBox(width: uiUnit(2)),
                        Expanded(
                            child: Container(
                                height: uiUnit(.5), color: darkElementColor)),
                      ],
                    ],
                  ),
                ),
                !widget.isChildGoal
                    ? GlassGoalsIconButton(
                        onPressed: () {
                          AppContext.of(context).syncClient.modifyGoal(
                              GoalDelta(
                                  id: widget.path.goalId,
                                  logEntry: ArchiveNoteLogEntry(
                                      id: widget.textEntry.id,
                                      creationTime: DateTime.now())));
                          widget.onRefresh();
                        },
                        icon: Icons.delete)
                    : Container(),
              ],
            ),
          ),
        IntrinsicHeight(
          child: Stack(
            children: [
              DropzoneView(
                onCreated: (controller) {
                  this._dropzoneController = controller;
                },
                cursor: _dropify ? CursorType.grabbing : null,
                onDrop: (dynamic ev) async {
                  setState(() {
                    this._dropify = false;
                  });
                  final mimeType =
                      await this._dropzoneController.getFileMIME(ev);
                  print(mimeType);
                  if (mimeType.startsWith("image/") ||
                      mimeType.startsWith("video/") ||
                      mimeType.startsWith("audio/")) {
                    final data = await this._dropzoneController.getFileData(ev);
                    final extension = mimeType.split("/")[1];
                    final filename = "${Uuid().v4()}.$extension";

                    await AppContext.of(context)
                        .cloudstoreService
                        .saveDataBytes(filename, data);
                    final text = _textController.text;
                    final newText =
                        text + "\n\n![image](glassgoals://$filename)";
                    _textController.text = newText;
                    _saveNote();
                  }
                },
                onLeave: () => {
                  setState(() {
                    this._dropify = false;
                  })
                },
                onHover: () {
                  if (!this._dropify) {
                    setState(() {
                      this._dropify = true;
                    });
                  }
                },
              ),
              _editing
                  ? Actions(
                      actions: {
                        AcceptMultiLineTextIntent:
                            CallbackAction(onInvoke: (_) => _saveNote()),
                        CancelIntent:
                            CallbackAction(onInvoke: (_) => _discardEdit()),
                      },
                      child: TextField(
                        autocorrect: false,
                        controller: _textController,
                        decoration: null,
                        maxLines: null,
                        style: mainTextStyle,
                        onTapOutside: (_) {
                          if (widget.textEntry.text != null &&
                              _textController.text != widget.textEntry.text) {
                            _saveNote();
                          }
                          setState(() {
                            _editing = false;
                          });
                        },
                        focusNode: _focusNode,
                      ),
                    )
                  : MarkdownBody(
                      data: _textController.text,
                      selectable: true,
                      listItemCrossAxisAlignment:
                          MarkdownListItemCrossAxisAlignment.start,
                      imageBuilder: (uri, title, alt) {
                        if (uri.scheme == "glassgoals") {
                          final assetFileName = uri.toString().split("://")[1];
                          final extension = assetFileName.split(".")[1];
                          final downloadUrl = _downloadUrls[assetFileName];
                          final videoController =
                              _videoControllers[assetFileName];
                          final audioPlayer = _audioPlayers[assetFileName];

                          switch (extension) {
                            case "jpg":
                            case "jpeg":
                            case "png":
                              return downloadUrl != null
                                  ? Image.network(downloadUrl)
                                  : FutureBuilder(
                                      future: AppContext.of(context)
                                          .cloudstoreService
                                          .getDownloadUrl(assetFileName)
                                          .then((url) {
                                        _downloadUrls[assetFileName] = url;
                                        return url;
                                      }),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return Container();
                                        }

                                        return Image.network(
                                            snapshot.requireData);
                                      });
                            case "mpeg":
                              return audioPlayer != null
                                  ? AudioPlayerWidget(player: audioPlayer)
                                  : FutureBuilder(
                                      future: (_downloadUrls[assetFileName] !=
                                                  null
                                              ? Future.value(
                                                  _downloadUrls[assetFileName]!)
                                              : AppContext.of(context)
                                                  .cloudstoreService
                                                  .getDownloadUrl(
                                                      assetFileName))
                                          .then((url) async {
                                        _downloadUrls[assetFileName] = url;
                                        var player =
                                            _audioPlayers[assetFileName];

                                        if (player == null) {
                                          player = AudioPlayer();
                                          player.play(UrlSource(url));
                                          player.stop();
                                        }

                                        return player;
                                      }),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return Container();
                                        }

                                        return AudioPlayerWidget(
                                            player: snapshot.requireData);
                                      });
                            case "mp4":
                              return videoController?.value.isInitialized ==
                                      true
                                  ? AspectRatio(
                                      aspectRatio:
                                          videoController!.value.aspectRatio,
                                      child: VideoPlayer(videoController),
                                    )
                                  : FutureBuilder(
                                      future: (_downloadUrls[assetFileName] !=
                                                  null
                                              ? Future.value(
                                                  _downloadUrls[assetFileName]!)
                                              : AppContext.of(context)
                                                  .cloudstoreService
                                                  .getDownloadUrl(
                                                      assetFileName))
                                          .then((url) async {
                                        _downloadUrls[assetFileName] = url;
                                        var controller =
                                            _videoControllers[assetFileName];

                                        if (controller == null) {
                                          controller = VideoPlayerController.networkUrl(
                                              Uri.parse(url),
                                              videoPlayerOptions: VideoPlayerOptions(
                                                  webOptions: VideoPlayerWebOptions(
                                                      controls:
                                                          VideoPlayerWebOptionsControls
                                                              .enabled())));
                                          _videoControllers[assetFileName] =
                                              controller;
                                        }

                                        if (!controller.value.isInitialized) {
                                          await controller.initialize();
                                        }

                                        return controller;
                                      }),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return Container();
                                        }

                                        return AspectRatio(
                                          aspectRatio: snapshot
                                              .requireData.value.aspectRatio,
                                          child:
                                              VideoPlayer(snapshot.requireData),
                                        );
                                      });
                            default:
                              return Container(
                                  color: Colors.grey,
                                  child: Text(
                                      "Unsupported asset type: $extension"));
                          }
                        }
                        return Image.network(uri.toString());
                      },
                      bulletBuilder: (params) {
                        switch (params.style) {
                          case BulletStyle.orderedList:
                            return Text("${params.index + 1}.",
                                style: TextStyle(
                                    fontSize: 20,
                                    textBaseline: TextBaseline.alphabetic));
                          case BulletStyle.unorderedList:
                            return Padding(
                              padding: EdgeInsets.only(top: uiUnit(3)),
                              child: Text("⬤",
                                  style: TextStyle(fontSize: 6.5),
                                  textAlign: TextAlign.center),
                            );
                        }
                      },
                      onTapText: () {
                        if (!widget.isChildGoal) {
                          setState(() {
                            if (_textController.text == DEFAULT_SUMMARY_TEXT ||
                                _textController.text ==
                                    DEFAULT_CONTEXT_COMMENT_TEXT) {
                              _textController.selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: _textController.text.length);
                            }

                            _editing = true;
                            _focusNode.requestFocus();
                          });
                        }
                      },
                      onTapLink: (text, href, title) async {
                        if (href == null) {
                          return;
                        }

                        final url = Uri.parse(href);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                      styleSheet: MarkdownStyleSheet(
                        textScaler: TextScaler.linear(1.05),
                        p: _textController.text == DEFAULT_SUMMARY_TEXT ||
                                _textController.text ==
                                    DEFAULT_CONTEXT_COMMENT_TEXT
                            ? mainTextStyle.copyWith(color: Colors.black54)
                            : mainTextStyle,
                      )),
              if (this._dropify)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Text(
                      'Drop here',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
