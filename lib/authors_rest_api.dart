import 'dart:async';
import 'package:angel_auth/angel_auth.dart';
import 'package:angel_file_service/angel_file_service.dart';
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_security/hooks.dart' as auth_hooks;
import 'package:angel_validate/server.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

const FileSystem fs = const LocalFileSystem();

Future configureServer(Angel app) async {
  var auth = new AngelAuth<User>(
    allowCookie: false,

    // Typically, this will be loaded from a configuration file.
    // However, this article doesn't cover configuration.
    jwtKey: 'blQZtlqOBVffr6WWCXKyKwbuTpgk5E1K',
  );

  // The `serializer` typically returns a user's ID.
  auth.serializer = (User user) async => user.id;

  // The `deserializer` usually returns a lookup by ID.
  // However, we're not covering that today.
  //
  // Check out this article for an explanation:
  // https://medium.com/the-angel-framework/logging-users-in-to-angel-applications-ccf32aba0dac
  auth.deserializer = (id) => new User(
        username: 'angel',
        password: 'framework',
      );

  // Configure the application to decode JWT's.
  app.use(auth.decodeJwt);
  await app.configure(auth.configureServer);

  // Enable username+password authentication
  var localAuthStrategy = new LocalAuthStrategy((username, password) async {
    // In the real world, we wouldn't actually be using hard-coded credentials, but...
    if (username == 'angel' && password == 'framework')
      return new User(
        username: username,
        password: password,
      );
  });

  auth.strategies.add(localAuthStrategy);
  app.post('/auth/local', auth.authenticate('local'));

  HookedService service = app.use(
    '/api/authors',
    new JsonFileService(fs.file('authors_db.json')),
  );

  var authorValidator = new Validator({
    'email': isEmail,
    'location': isAlphaDash,
    'name,github,twitter,latest_article_published': isNonEmptyString,
  });

  var createAuthorValidator = authorValidator.extend({})
    ..requiredFields.addAll([
      'name',
      'email',
      'location',
    ]);

  // Validation on create
  service.beforeCreated.listen(validateEvent(createAuthorValidator));

  service.beforeCreated.listen((e) async {
    String email = e.data['email'], emailLower = email.toLowerCase();

    // See if another author has this email.
    Iterable existing = await e.service.index({
      'query': {
        'email_lower': emailLower,
      }
    });

    if (existing.isNotEmpty) {
      throw new AngelHttpException.forbidden(
          message: 'Somebody else has this email.');
    }

    // Otherwise, save the lowercased email.
    e.data['email_lower'] = emailLower;
  });

  // Validation on modify+update (also validates create)
  service.beforeModify(validateEvent(authorValidator));

  service.before([
    HookedServiceEvent.created,
    HookedServiceEvent.modified,
    HookedServiceEvent.updated,
    HookedServiceEvent.removed,
  ], auth_hooks.restrictToAuthenticated());
}

class User {
  int id;
  String username, password;
  User({this.id, this.username, this.password});
}
