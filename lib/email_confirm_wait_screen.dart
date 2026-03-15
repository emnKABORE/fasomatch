import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailConfirmWaitScreen extends StatefulWidget {
  final String email;

  const EmailConfirmWaitScreen({super.key, required this.email});

  @override
  State<EmailConfirmWaitScreen> createState() => _EmailConfirmWaitScreenState();
}

class _EmailConfirmWaitScreenState extends State<EmailConfirmWaitScreen> {

  Timer? _timer;
  bool _loading=false;

  @override
  void initState() {
    super.initState();
    _startCheck();
  }

  void _startCheck(){
    _timer = Timer.periodic(const Duration(seconds:3), (_) async {

      final session = Supabase.instance.client.auth.currentSession;

      if(session != null){
        _timer?.cancel();

        if(!mounted) return;

        Navigator.pushReplacementNamed(context, "/swipe");
      }

    });
  }

  Future<void> _resendMail() async{

    setState(() {
      _loading=true;
    });

    try{

      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
        emailRedirectTo: "fasomatch://auth/callback",
      );

      if(!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email renvoyé"),
        ),
      );

    }catch(e){

      if(!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur : $e"),
        ),
      );

    }

    setState(() {
      _loading=false;
    });

  }

  @override
  void dispose(){
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){

    return Scaffold(

      body: Center(

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Icon(Icons.mark_email_read,size:80),

            const SizedBox(height:20),

            const Text(
              "Confirme ton email",
              style: TextStyle(
                fontSize:22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height:10),

            Text(
              widget.email,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height:30),

            const CircularProgressIndicator(),

            const SizedBox(height:30),

            TextButton(
              onPressed: _loading ? null : _resendMail,
              child: const Text(
                "Email non reçu ? Renvoyer",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )

          ],
        ),
      ),
    );
  }
}