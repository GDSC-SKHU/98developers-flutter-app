import 'package:bloc/bloc.dart';
import 'package:http/http.dart' as http;
import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

part 'google_auth_state.dart';

class GoogleAuthCubit extends Cubit<GoogleAuthState> {
  GoogleAuthCubit(this._secureStorage) : super(GoogleAuthInitial()) {
    _secureStorage;
    _googleSignIn;
    _fireBaseAuth;
  }

  final FlutterSecureStorage _secureStorage;
  final GoogleSignIn _googleSignIn = GoogleSignIn.standard(scopes: ["email"]);
  final FirebaseAuth _fireBaseAuth = FirebaseAuth.instance;

  //Sign in Google account
  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? _googleAccount = await _googleSignIn.signIn();

      if (_googleAccount != null) {
        final GoogleSignInAuthentication googleSignInAuthentication =
            await _googleAccount.authentication;

        final AuthCredential _credential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );
        await _secureStorage.write(
            key: "accessToken", value: _credential.accessToken);

        final UserCredential userCredential =
            await _fireBaseAuth.signInWithCredential(_credential);
        final User? _user = userCredential.user;

        //Save encrypt user data
        await _secureStorage.write(key: "userIdentifier", value: _user?.uid);
        await _secureStorage.write(
            key: "refreshToken", value: _user?.refreshToken);

        if (_user != null) {
          emit(GoogleAuthSuccess(user: _user));
          getUserData();
        } else {
          emit(GoogleAuthFailed(errorMessage: "Sign in failed."));
          emit(GoogleAuthLoading());
        }
      } else {
        emit(GoogleAuthFailed(errorMessage: "Canceled Google Sign in."));
      }
    } catch (error) {
      emit(GoogleAuthFailed(errorMessage: error.toString()));
    }
  }

  Future<void> getUserData() async {
    const String url = "http://zikiza.duckdns.org/users";
    String? accessToken =
        await _secureStorage.read(key: "accessToken").toString();
    try {
      var response = await http.get(
        Uri.parse(url),
        headers: {"accessToken": accessToken},
      );

      if (response.statusCode == 200) {
        print("getUserData(): http get user data successfully.");
      } else if (response.statusCode == 401) {
        print("getUserData(): Not valid access token. 401.");
      } else if (response.statusCode == 403) {
        print("getUserData(): http get user data failed. 403.");
      }
    } catch (error) {
      return print(error);
    }
  }

  //Sign out Google account
  Future<void> signOutWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      await _fireBaseAuth.signOut();
      await _secureStorage.deleteAll();
      emit(GoogleAuthInitial());
    } catch (error) {
      emit(GoogleSignOutFailed(errorMessage: error.toString()));
    }
  }
}
