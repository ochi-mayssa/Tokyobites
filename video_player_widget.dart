import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class CustomVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const CustomVideoPlayer({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _CustomVideoPlayerState createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = _extractYoutubeId(widget.videoUrl);
    _controller = YoutubePlayerController(
      initialVideoId: videoId ?? '',
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        disableDragSeek: true,
      ),
    );
  }

  String? _extractYoutubeId(String url) {
    try {
      final cleanedUrl = url.trim();
      if (cleanedUrl.contains('youtube.com/watch?v=')) {
        return cleanedUrl.split('v=')[1].split('&')[0];
      } else if (cleanedUrl.contains('youtu.be/')) {
        return cleanedUrl.split('youtu.be/')[1].split('?')[0];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.initialVideoId.isEmpty) {
      return _buildVideoErrorWidget();
    }

    return YoutubePlayer(
      controller: _controller,
      showVideoProgressIndicator: true,
      progressColors: ProgressBarColors(
        playedColor: Theme.of(context).colorScheme.secondary,
        handleColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Widget _buildVideoErrorWidget() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 40, color: Colors.red),
          SizedBox(height: 12),
          Text('Invalid Video URL', style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          )),
        ],
      ),
    );
  }
}