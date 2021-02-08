import 'package:flutter/material.dart';
import 'package:janus_client/Plugin.dart';
import 'package:janus_client/janus_client.dart';
import 'package:janus_client/utils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoCallExample extends StatefulWidget {
  @override
  _VideoCallExampleState createState() => _VideoCallExampleState();
}


class _VideoCallExampleState extends State<VideoCallExample> {
  JanusClient janusClient = JanusClient(iceServers: [
    RTCIceServer(
        url: "stun:40.85.216.95:3478",
        username: "onemandev",
        credential: "SecureIt"),
    RTCIceServer(
        url: "turn:40.85.216.95:3478",
        username: "onemandev",
        credential: "SecureIt")
  ], server: [
    'https://janus.onemandev.tech/janus',
    'wss://janus.onemandev.tech/janus/websocket',
  ], withCredentials: true, apiSecret: "SecureIt");
  Plugin publishVideo;
  TextEditingController nameController = TextEditingController();
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();
  MediaStream myStream;

  makeCall() async {
    await _localRenderer.initialize();
    _localRenderer.srcObject =
        await publishVideo.initializeMediaDevices(mediaConstraints: {
      "audio": true,
      "video": {
        "mandatory": {
          "minFrameRate": '60',
        },
        "facingMode": "user",
        "optional": [],
      }
    });
    RTCSessionDescription offerToCall = await publishVideo.createOffer();
    var body = {"request": "call", "username": nameController.text};
    publishVideo.send(
        message: body,
        jsep: offerToCall,
        onSuccess: () {
          print("Calling");
        },
        onError: (e) {
          print('got error in calling');
          print(e);
        });
    nameController.text = "";
  }

  registerDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        child: AlertDialog(
          title: Text("Register As"),
          content: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: "Your Name"),
                controller: nameController,
              ),
              RaisedButton(
                color: Colors.green,
                textColor: Colors.white,
                onPressed: () {
                  registerUser(nameController.text);
                },
                child: Text("Proceed"),
              )
            ],
          ),
        ));
  }

  makeCallDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        child: AlertDialog(
          title: Text("Call Registered User or wait for user to call you"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration:
                    InputDecoration(labelText: "Name Of Registered User to call"),
                controller: nameController,
              ),
              RaisedButton(
                color: Colors.green,
                textColor: Colors.white,
                onPressed: () {
                  makeCall();
                  Navigator.of(context).pop();
                },
                child: Text("Call"),
              )
            ],
          ),
        ));
  }

  @override
  void didChangeDependencies() async{
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    janusClient.connect(onSuccess: (sessionId) {
      janusClient.attach(Plugin(
          onRemoteStream: (remoteStream) {
            _remoteRenderer.srcObject=remoteStream;
          },
          plugin: "janus.plugin.videocall",
          onMessage: (msg, jsep) async {
            print('got onmsg');
            print(msg);
            var result = msg["result"];
            if (result != null) {
              if (result["event"] != null) {
                var event = result["event"];
                if (event == 'accepted') {
                  var peer = result["username"];
                  if (peer != null) {
                    debugPrint("Call started!");
                  } else {
                    // debugPrint(peer + " accepted the call!");
                  }
                  // Video call can start
                  if (jsep != null) publishVideo.handleRemoteJsep(jsep);
                } else if (event == 'incomingcall') {
                  Navigator.pop(context);
                  debugPrint("Incoming call from " + result["username"] + "!");
                  var yourusername = result["username"];

                  _localRenderer.srcObject=await publishVideo.initializeMediaDevices();

                  if (jsep != null) publishVideo.handleRemoteJsep(jsep);
                  // Notify user
                  var offer = await publishVideo.createAnswer();
                  var body = {"request": "accept"};
                  publishVideo.send(
                      message: body,
                      jsep: offer,
                      onSuccess: () {
                        print('call connected');
                      });
                  // print(publishVideo.webRTCHandle.pc.);
                }
                else if(event == 'hangup') {
                  await cleanUpAndBack();
                }
              }
            }
          },
          onSuccess: (plugin) {
            setState(() {
              publishVideo = plugin;
              registerDialog();
            });
          }));
    });
  }

  registerUser(userName) {
    if (publishVideo != null) {
      publishVideo.send(
          message: {"request": "register", "username": userName},
          onSuccess: () {
            print("User registered");
            nameController.text = "";
            Navigator.pop(context);
            makeCallDialog();
          },
          onError: (error) {
            print(error);
          });
    }
  }

 Future<void> cleanUpAndBack()async{


    await publishVideo.destroy();
    janusClient.destroy();
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Column(
          children: [
            Expanded(
              child: RTCVideoView(
                _remoteRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,

              ),
            ),
            Expanded(
                child: Container(
              width: double.maxFinite,
              decoration:
                  BoxDecoration(boxShadow: [BoxShadow(color: Colors.black45)]),
              child: RTCVideoView(
                _localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ))
          ],
        ),
        Align(
          alignment: Alignment.topRight,
          child:Padding(child:IconButton(
                  icon: Icon(Icons.refresh), color: Colors.white, onPressed: () {
            publishVideo.switchCamera();
              }),padding: EdgeInsets.all(25),),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child:Padding(child:CircleAvatar(
              backgroundColor: Colors.red,
              radius:30,
              child:IconButton(
              icon: Icon(Icons.call_end), color: Colors.white, onPressed: () {
                publishVideo.send(message: {'request':'hangup'},onSuccess: ()async{
                 await cleanUpAndBack();
                });
          })),padding: EdgeInsets.all(10),),
        )
      ]),
    );
  }
  @override
  void dispose()async{
    // TODO: implement dispose
    super.dispose();

  }
}
