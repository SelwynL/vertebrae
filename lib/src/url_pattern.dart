// Copyright 2013, the Dart project authors. All rights reserved. Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//    and the following disclaimer
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//    conditions and the following disclaimer in the documentation and/or other materials provided
//    with the distribution.
//  * Neither the name of Google Inc. nor the names of its contributors may be used to endorse or
//    promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER  IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


//library url_pattern;
part of router;

// From the PatternCharacter rule here:
// http://ecma-international.org/ecma-262/5.1/#sec-15.10 removed '( and ')' since we'll never escape them when not in a group
final _specialChars = new RegExp(r'[\^\$\.\|\+\[\]\{\}]');

UrlPattern urlPattern(String p) => new UrlPattern(p);

/**
 * A pattern, similar to a [RegExp], that is designed to match against URL
 * paths, easily return groups of a matched path, and produce paths from a list
 * of arguments - this is they are "reversible".
 *
 * `UrlPattern`s also allow for handling plain paths and URLs with a fragment in
 * a uniform way so that they can be used for client side routing on browsers
 * that support `window.history.pushState` as well as legacy browsers.
 *
 * The differences from a plain [RegExp]:
 *  * All non-literals must be in a group. Everything outside of a groups is
 *    considered a literal and special regex characters are escaped.
 *  * There can only be one match, and it must match the entire string. `^` and
 *    `$` are automatically added to the beginning and end of the pattern,
 *    respectively.
 *  * The pattern must be un-ambiguous, eg `(.*)(.*)` is not allowed at the
 *    top-level.
 *  * The hash character (#) matches both '#' and '/', and it is only allowed
 *    once per pattern. Hashes are not allowed inside groups.
 *
 * With those differences, `UrlPatterns` become much more useful for routing
 * URLs and constructing them, both on the client and server. The best practice
 * is to define your application's set of URLs in a shared library.
 *
 * urls.dart:
 *
 *     library urls;
 *
 *     final articleUrl = new UrlPattern(r'/articles/(\d+)');
 *
 * server.dart:
 *
 *     import 'urls.dart';
 *     import 'package:route/server.dart';
 *
 *     main() {
 *       var server = new HttpServer();
 *       server.addRequestHandler(matchesUrl(articleUrl), serveArticle);
 *     }
 *
 *     serveArcticle(req, res) {
 *       var articleId = articleUrl.parse(req.path)[0];
 *       // ...
 *     }
 *
 * Use with older browsers
 * -----------------------
 *
 * Since '#' matches both '#' and '/' it can be used in as a path separator
 * between the "static" portion of your URL and the "dynamic" portion. The
 * dynamic portion would be the part that change when a user navigates to new
 * data that's loaded dynamically rather than loading a new page.
 *
 * In newer browsers that support `History.pushState()` an entire new path can
 * be pushed into the location bar without reloading the page. In older browsers
 * only the fragment can be changed without reloading the page. By matching both
 * characters, and by producing either, we can use pushState in newer browsers,
 * but fall back to fragments when necessary.
 *
 * Examples:
 *
 *     var pattern = new UrlPattern(r'/app#profile/(\d+)');
 *     pattern.matches('/app/profile/1234'); // true
 *     pattern.matches('/app#profile/1234'); // true
 *     pattern.reverse([1234], useFragment: true); // /app#profile/1234
 *     pattern.reverse([1234], useFragment: false); // /app/profile/1234
 */
class UrlPattern implements Pattern {
  final String pattern;
  RegExp _regex;
  bool _hasFragment;
  RegExp _baseRegex;

  UrlPattern(this.pattern) {
    _parse(pattern);
  }

  RegExp get regex => _regex;

  String reverse(Iterable args, {bool useFragment: false}) {
    var sb = new StringBuffer();
    var chars = pattern.split('');
    var argsIter = args.iterator;

    int depth = 0;
    int groupCount = 0;
    bool escaped = false;

    for (int i = 0; i < chars.length; i++) {
      var c = chars[i];
      if (c == '\\' && escaped == false) {
        escaped = true;
      } else {
        if (c == '(') {
          if (escaped && depth == 0) {
            sb.write(c);
          }
          if (!escaped) depth++;
        } else if (c == ')') {
          if (escaped && depth == 0) {
            sb.write(c);
          } else if (!escaped) {
            if (depth == 0) throw new ArgumentError('unmatched parentheses');
            depth--;
            if (depth == 0) {
              // append the nth arg
              if (argsIter.moveNext()) {
                sb.write(argsIter.current.toString());
              } else {
                throw new ArgumentError('more groups than args');
              }
            }
          }
        } else if (depth == 0) {
          if (c == '#' && !useFragment) {
            sb.write('/');
          } else {
            sb.write(c);
          }
        }
        escaped = false;
      }
    }
    if (depth > 0) {
      throw new ArgumentError('unclosed group');
    }
    return sb.toString();
  }

  /**
   * Parses a URL path, or path + fragment, and returns the group matches.
   * Throws [ArgumentError] if this pattern does not match [path].
   */
  List<String> parse(String path) {
    var match = regex.firstMatch(path);
    if (match == null) {
      throw new ArgumentError('no match for $path');
    }
    var result = <String>[];
    for (int i = 1; i <= match.groupCount; i++) {
      result.add(match[i]);
    }
    return result;
  }

  /**
   * Returns true if this pattern matches [path].
   */
  bool matches(String str) => _matches(regex, str);

  Match matchAsPrefix(String string, [int start = 0]) =>
      regex.matchAsPrefix(string, start);

  // TODO(justinfagnani): file bug for similar method to be added to Pattern
  bool _matches(Pattern p, String str) {
    var iter = p.allMatches(str).iterator;
    if (iter.moveNext()) {
      var match = iter.current;
      return (match.start == 0) && (match.end == str.length)
          && (!iter.moveNext());
    }
    return false;
  }

  /**
   * Returns true if the path portion of the pattern, the part before the
   * fragment, matches [str]. If there is no fragment in the pattern, this is
   * equivalent to calling [matches].
   *
   * This method is most useful on a server that is serving the HTML of a
   * single page app. Clients that don't support pushState will not send the
   * fragment to the server, so the server will have to handle just the path
   * part.
   */
  bool matchesNonFragment(String str) {
    if (!_hasFragment) {
      return matches(str);
    } else {
      return _matches(_baseRegex, str);
    }
  }

  Iterable<Match> allMatches(String str) {
    return regex.allMatches(str);
  }

  bool operator ==(other) =>
      (other is UrlPattern) && (other.pattern == pattern);

  int get hashCode => pattern.hashCode;

  String toString() => pattern.toString();

  _parse(String pattern) {
    var sb = new StringBuffer();
    int depth = 0;
    int lastGroupEnd = -2;
    bool escaped = false;

    sb.write('^');
    var chars = pattern.split('');
    for (var i = 0; i < chars.length; i++) {
      var c = chars[i];

      if (depth == 0) {
        // outside of groups, transform the pattern to matches the literal
        if (c == r'\') {
          if (escaped) {
            sb.write(r'\\');
          }
          escaped = !escaped;
        } else {
          if (_specialChars.hasMatch(c)) {
            sb.write('\\$c');
          } else if (c == '(') {
            if (escaped) {
              sb.write(r'\(');
            } else {
              sb.write('(');
              if (lastGroupEnd == i - 1) {
                throw new ArgumentError('ambiguous adjecent top-level groups');
              }
              depth = 1;
            }
          } else if (c == ')') {
            if (escaped) {
              sb.write(r'\)');
            } else {
              throw new ArgumentError('unmatched parenthesis');
            }
          } else if (c == '#') {
            _setBasePattern(sb.toString());
            sb.write('[/#]');
          } else {
            sb.write(c);
          }
          escaped = false;
        }
      } else {
        // in a group, don't modify the pattern, but track escaping and depth
        if (c == '(' && !escaped) {
          depth++;
        } else if (c == ')' && !escaped) {
          depth--;
          if (depth < 0) throw new ArgumentError('unmatched parenthesis');
          if (depth == 0) {
            lastGroupEnd = i;
          }
        } else if (c == '#') {
          // TODO(justinfagnani): what else should be banned in groups? '/'?
          throw new ArgumentError('illegal # inside group');
        }
        escaped = (c == r'\' && !escaped);
        sb.write(c);
      }
    }
    sb.write(r'$');
    _regex = new RegExp(sb.toString());
  }

  _setBasePattern(String basePattern) {
    if (_hasFragment == true) {
      throw new ArgumentError('multiple # characters');
    }
    _hasFragment = true;
    _baseRegex = new RegExp('$basePattern\$');
  }
}