SafeSlinger iOS Client
===================
The open source SafeSlinger Exchange library is a secure and easy to use method of exchanging public keys or other authentication data, with strong protection from Man-In-The-Middle (MITM) attacks. Our goal is to make exchanging public keys as simple as possible without sacrificing security. Our [research paper][10], presented at MobiCom '13, provides a technical analysis of SafeSlinger's key exchange properties.

Library Features:

- Open source makes security audits easy.
- The only secure simultaneous key exchange for up to 10 people.
- Easy to implement and use.
- Cross-platform Android and iOS ([iOS library][11] coming Spring 2014).
- Protection from Man-In-The-Middle attacks during key exchanges.
- Exchange keys either in person or remote.

The SafeSlinger secure key exchange is implemented cross-platform for [Android][14] and [iOS][11] devices. Keys are exchanged using a simple server implementation on [App Engine][15].

Repository iOS Projects
=======

- **/safeslinger-exchange** contains the full application project source for the [SafeSlinger Messenger][3] application. This project is a very rich implementation of a safeslinger secure exchange if you want an example of how to use the exchange to verify public keys in your own applications.
- **/airship_lib** contains the client [Urban Airship][16] library for managing push messages.
- **/openssl-ios** contains the [OpenSSL][17] library.
- **/sha3-ios** contains only the Keccak portions of the [sphlib 3.0][4] library.

Running the Demo
========
iOS demo forthcoming.

Add Secure Exchange to your iOS App
========
iOS integration instructions forthcoming.

Contact
=======

* SafeSlinger [Project Website][9]
* Please submit [Bug Reports][12]!
* Looking for answers, try our [FAQ][7]!
* Support: <safeslingerapp@gmail.com>

License
=======
	The MIT License (MIT)

	Copyright (c) 2010-2014 Carnegie Mellon University

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.



 [1]: http://play.google.com/store/apps/details?id=edu.cmu.cylab.starslinger
 [2]: http://play.google.com/store/apps/details?id=edu.cmu.cylab.starslinger.demo
 [3]: http://itunes.apple.com/app/safeslinger/id493529867
 [4]: http://www.saphir2.com/sphlib
 [5]: http://code.google.com/p/android-vcard
 [6]: http://www.youtube.com/watch?v=IFXL8fUqNKY
 [7]: http://www.cylab.cmu.edu/safeslinger/faq.html
 [8]: http://www.cylab.cmu.edu/safeslinger/images/android-StartDemo.png
 [9]: http://www.cylab.cmu.edu/safeslinger
 [10]: http://sparrow.ece.cmu.edu/group/pub/farb_safeslinger_mobicom2013.pdf
 [11]: http://github.com/SafeSlingerProject/SafeSlinger-iOS
 [12]: http://github.com/SafeSlingerProject/SafeSlinger-iOS/issues
 [13]: http://developer.android.com/reference/android/support/v7/app/package-summary.html 
 [14]: http://github.com/SafeSlingerProject/SafeSlinger-Android
 [15]: http://github.com/SafeSlingerProject/SafeSlinger-AppEngine
 [16]: http://www.urbanairship.com
 [17]: http://www.openssl.org
 
 
