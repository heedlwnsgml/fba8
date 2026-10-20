import 'package:flutter/material.dart';
import 'directions_surface_stub.dart'
    if (dart.library.io) 'directions_surface_native.dart'
    if (dart.library.js_interop) 'directions_surface_web.dart' as surface;

Uri itineraryEmbeddedDirections(Uri route) {
  if(['www.google.com','maps.google.com'].contains(route.host) && route.path.startsWith('/maps/embed'))return route;
  return Uri.https('maps.google.com','/maps',{
    'saddr':route.queryParameters['origin']??'', 'daddr':route.queryParameters['destination']??'',
    'dirflg':switch(route.queryParameters['travelmode']){'driving'=>'d','walking'=>'w','bicycling'=>'b',_=>'r'},
    'hl':'ko','output':'embed',
  });
}

Future<void> showDirectionsPreview(BuildContext context,Uri route,{Widget? content,String? details})=>showDialog<void>(
  context:context,barrierDismissible:true,builder:(c)=>Dialog(
    insetPadding:const EdgeInsets.symmetric(horizontal:20,vertical:36),clipBehavior:Clip.antiAlias,
    child:SizedBox(width:760,height:MediaQuery.sizeOf(c).height*.82,child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(18,6,6,6),child:Row(children:[
        const Icon(Icons.directions,color:Color(0xFF2563EB)),const SizedBox(width:10),
        const Expanded(child:Text('실제 경로 보기',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold))),
        IconButton(tooltip:'경로 미리보기 닫기',onPressed:()=>Navigator.pop(c),icon:const Icon(Icons.close)),
      ])),
      const Divider(height:1),
      Expanded(child:content??surface.directionsSurface(route,itineraryEmbeddedDirections(route))),
      const Padding(padding:EdgeInsets.all(10),child:Text('바깥 영역을 누르면 일정으로 돌아갑니다.',style:TextStyle(fontSize:12,color:Colors.black54))),
    ])),
  ),
);
