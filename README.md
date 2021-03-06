
[![Build Status](https://travis-ci.org/SafeSlingerProject/SafeSlinger-iOS.svg?branch=master)](https://travis-ci.org/SafeSlingerProject/SafeSlinger-iOS)

Quick Links:
[Downloads](https://github.com/SafeSlingerProject/SafeSlinger-Media/wiki/Platforms),
[Wiki](https://github.com/SafeSlingerProject/SafeSlinger-Media/wiki),
[Support, Translations, Contributing](https://github.com/SafeSlingerProject/SafeSlinger-Media/wiki/Contributing),
[Research Paper](http://sparrow.ece.cmu.edu/group/pub/farb_safeslinger_mobicom2013.pdf),
[Project Website](http://www.cylab.cmu.edu/safeslinger)

SafeSlinger iOS Client Projects

- **/safeslingerexchange** Contains the library project you can add to your own iOS applications. Both the safeslinger-demo and safeslinger-messenger application projects utilize this library to execute the exchange.
- **/safeslingerdemo** Contains the simple [SafeSlinger Exchange Developer application](https://itunes.apple.com/app/safeslinger-exchange-for-developers/id909442873) project which shows the minimum requirements to run a safeslinger secure exchange.
- **/safeslingermessenger** Contains the full application project source for the [SafeSlinger Messenger](http://itunes.apple.com/app/safeslinger/id493529867) application. This project is a very rich implementation of a safeslinger secure exchange if you want an example of how to use the exchange to verify public keys in your own applications.
- **/localizations** Contains localization support used in iOS platform.
- **/openssl-ios** Contains the complied [OpenSSL](http://www.openssl.org) library.
- **/sha3-ios-binary** Contains only the Keccak portions of the [sphlib 3.0](http://www.saphir2.com/sphlib) library.

Running the Developer's App on Xcode
========

Developer's App Requirements:

1. Must be installed on a minimum of 2 devices.
2. An Internet connection must be active.
3. 'Server Host Name' can be your own server, OR use ours: `https://slinger-dev.appspot.com`
4. 'My Secret' can be any information.

![Developer's App Main Screen](https://www.dropbox.com/s/thhmk3nb2twi2js/demo-1.png?raw=1)

To execute SafeSlinger Exchange Developer app using Xcode and iPhone simulator:

1. Install Xcode (at least 5.x) on your Mac OS.
2. Download the whole source code tree from SafeSlinger iOS Project.
3. Open safeslingerdemo project using Xcode and select iPhone simulator as your build target.
4. Build and Run the SafeSlinger Exchange Developer's app on iPhone simulator.


Add Secure Exchange to your iOS App
========
## Xcode Setup

- Add the safeslingerexchange project as a subproject into your project.

![AddLibrary1](https://www.dropbox.com/s/mfl16i7c4ut2f3n/addlibrary-1.png?raw=1)

- Add **-ObjC** to *Other Linker Flags* in your target settings.

![AddLibrary2](https://www.dropbox.com/s/8yxa0xr4cs96xty/addlibrary-2.png?raw=1)

- Add the compiled static library **libsafeslingerexchange.a** to link to the library in your project.

![AddLibrary3](https://www.dropbox.com/s/p3x2l86aopfg4t4/addlibrary-3.png?raw=1)

- Drag the **exchangeui** bundle from the safeslingerexchange subproject to your Bundle resource as well.

![AddLibrary4](https://www.dropbox.com/s/hco2g5d9674mec2/addlibrary-4.png?raw=1)

- Select building target as safeslingerexchange static library and then build.

- Make sure your UI controller is embedded in the navigation controller. For example, you can add a navigation controller to your UI through clicking *Edit* -> *Embed In* -> *Navigation Controller*.

![AddLibrary5](https://www.dropbox.com/s/7ek5wcvh95rycps/addlibrary-5.png?raw=1)

## Delegate Implementation
Implement the SafeSlinger delegate function on your UI controller, e.g., ViewController.

- Import the SafeSlinger header into your project.

```
#import <safeslingerexchange/safeslingerexchange.h>
```

- Add the SafeSlinger protocol object into your UIViewController, e.g.,

```
@interface ViewController : UIViewController <SafeSlingerDelegate>
{
    // safeslinger exchange object
    safeslingerexchange *proto;
}
@property (nonatomic, retain) safeslingerexchange *proto;
```

- To begin a SafeSlinger exchange, you can initialize the SafeSlinger protocol with the **SetupExchange** method and begin the exchange through calling **BeginExchange**, e.g., 

```
-(IBAction)BegineExchange:(id)sender
{
    proto = [[safeslingerexchange alloc]init];
    
    // ServerHost: safeslinger exchange server, e.g., https://slinger-dev.appspot.com by default
    // Version Number: current minimum protocol version is 1.7.0
    // Return YES when setup is correct.
    
    NSString *_data = @"This is a secret.";
    NSString *_host = @"https://slinger-dev.appspot.com";
    
    if([proto SetupExchange: self ServerHost:_host VersionNumber:@"1.7.0"])
        [proto BeginExchange: [_data dataUsingEncoding:NSUTF8StringEncoding]];
    
    // Call BeginExcahnge with your NSData object.
}
```

- After calling **BeginExchange**, the proto Object will navigate your UI to the exchange GUI through the embedded navigation controller.

- After a SafeSlinger exchange, your UI has to implement SafeSlingerDelegate protocol to handle either gathered data from other participants when the exchange finishes successfully, or errors when the protocol fails.

```
#pragma SafeSlingerDelegate Methods
- (void) EndExchange: (int)status ErrorString: (NSString*)error ExchangeSet: (NSArray*)exchange_set
{
	// we need to push back to the current UI
    [self.navigationController popToViewController:self animated:YES];
    
    switch(status)
    {
        case RESULT_EXCHANGE_OK:
            // Succeed, parse the exchanged data
            [self ParseData:exchange_set];
            break;
        case RESULT_EXCHANGE_CANCELED:
            // Failed, handle canceled result
            {
                NSLog(@"Exchange Error: %@", error);
            }
            break;
        default:
            break;
    }
}

/*	
 *	ParseData is just an example to show how we process the gathered data from exchanged parties. 
 *	We expect exchanged data are UTF-8 encoded strings.
 */
- (void) ParseData: (NSArray*) exchangeset
{
    int i = 0;
    NSMutableString *result = [NSMutableString string];
    for (i =0; i<[exchangeset count];i++)
    {
        [result appendFormat: @"Secret(%d): %@", i, [[NSString alloc] initWithData:[exchangeset objectAtIndex:i] encoding:NSUTF8StringEncoding]];
        [result appendString: @"\n"];
    }
    
    NSLog(@"Gathered Data Set: %@", result);
}
```

- Build your application and run the app on iOS devices or simulator.

License
=======
	The MIT License (MIT)

	Copyright (c) 2010-2015 Carnegie Mellon University

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




 
 
