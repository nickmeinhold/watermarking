import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';

class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, UserModel>(
      distinct: true,
      converter: (Store<AppState> store) => store.state.user,
      builder: (BuildContext context, UserModel user) {
        if (user.waiting || user.photoUrl == null) {
          return const Padding(
            padding: EdgeInsets.only(right: 15.0),
            child: CircularProgressIndicator(
              value: null,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: PopupMenuButton<String>(
            offset: const Offset(0, 48),
            onSelected: (value) async {
              if (value == 'signout') {
                // Sign out from Google first
                await GoogleSignIn.instance.signOut();
                // Then sign out from Firebase
                if (context.mounted) {
                  StoreProvider.of<AppState>(context).dispatch(ActionSignout());
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'signout',
                child: Row(
                  children: [
                    const Icon(Icons.logout),
                    const SizedBox(width: 8),
                    const Text('Sign out'),
                  ],
                ),
              ),
            ],
            child: Container(
              width: 40.0,
              height: 40.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: NetworkImage(user.photoUrl!),
                  fit: BoxFit.cover,
                ),
                border: Border.all(
                  color: Colors.white,
                  width: 2.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
