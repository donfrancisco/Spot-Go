//
//  SGMapViewController.m
//  SpotAndGo
//
//  Created by Truman, Christopher on 4/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SGMapViewController.h"
#import "SGDetailCardView.h"
#import "SVHTTPClient.h"
#import "SGAnnotation.h"
#import <CoreLocation/CoreLocation.h>
#import <QuartzCore/QuartzCore.h>
#import "YRDropdownView.h"
#import "NVPolylineAnnotation.h"
#import "NVPolylineAnnotationView.h"

@interface SGMapViewController ()

@end

@implementation SGMapViewController
@synthesize mapView;
@synthesize placeResultCardView, currentPlaces, currentCategory, authStatus, polylineArray;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    // Custom initialization
    [self.mapView setDelegate:self];
  }
  return self;
}

- (void)viewWillAppear:(BOOL)animated {
  NSError *error;
  
  if (![[GANTracker sharedTracker] trackPageview:@"/map"
                                       withError:&error]) {
    NSLog(@"error in trackPageview");
  }
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(chosePlace:) name:@"choice" object:nil];
  [self.mapView setShowsUserLocation:YES];

  [self.mapView setUserTrackingMode:MKUserTrackingModeFollowWithHeading animated:YES];
  [self.navigationController setNavigationBarHidden:NO animated:YES];
  [self.navigationController.navigationBar setTintColor:[UIColor colorWithRed:226/255.0f green:225/255.0f blue:222/255.0f alpha:1]];

  
  self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"spotgo_logo.png"]];
  self.placeResultCardView = [[SGDetailCardView alloc] initWithFrame:CGRectMake(0, 216, 320, 200)];
  [[self view] addSubview:placeResultCardView];
  currentCategory = [[NSUserDefaults standardUserDefaults] objectForKey:@"category"];
  authStatus = [CLLocationManager authorizationStatus];
}

- (void)viewDidAppear:(BOOL)animated {
  NSDictionary * appearance = [NSDictionary dictionaryWithObjectsAndKeys:
                               [UIColor blackColor], UITextAttributeTextColor,
                               [UIColor grayColor], UITextAttributeTextShadowColor, nil];
  UIBarButtonItem * item = self.navigationController.navigationItem.backBarButtonItem;
  [item setTitleTextAttributes:appearance forState:UIControlStateNormal];
  [TestFlight passCheckpoint:@"SGMapViewController Appeared"];
  if (authStatus == kCLAuthorizationStatusAuthorized) {
    [self.mapView setRegion:MKCoordinateRegionMakeWithDistance([self.mapView userLocation].coordinate, kDefaultZoomToStreetLatMeters, kDefaultZoomToStreetLonMeters) animated:YES];
    
    [self performSearch];
  } else{
    [TestFlight passCheckpoint:@"locationDisabled"];
    [YRDropdownView showDropdownInView:self.view
     title:@"Location Disabled"
     detail:@"You can enable location for Spot+Go in your iPhone settings under \"Location Services\"."
     image:[UIImage imageNamed:@"dropdown-alert"]
     animated:YES
     hideAfter:3];
  }
}

-(void)viewDidDisappear:(BOOL)animated{
  [self.mapView removeAnnotations:self.mapView.annotations];
}

- (void)performSearch {
  [TestFlight passCheckpoint:@"performSearch"];
  NSArray * locationArray = [NSArray arrayWithObjects:[NSNumber numberWithFloat:[self.mapView userLocation].coordinate.latitude] ?[NSNumber numberWithFloat:[self.mapView userLocation].coordinate.latitude]:[NSNumber numberWithFloat:kDefaultCurrentLat],[NSNumber numberWithFloat:[self.mapView userLocation].coordinate.longitude] ?[NSNumber numberWithFloat:[self.mapView userLocation].coordinate.longitude]:[NSNumber numberWithFloat:kDefaultCurrentLng], nil];

//  NSArray * locationArray = [NSArray arrayWithObjects:[NSNumber numberWithFloat:kDefaultCurrentLat],[NSNumber numberWithFloat:kDefaultCurrentLng], nil];
  NSDictionary * postDictionary = [NSDictionary dictionaryWithObjectsAndKeys:currentCategory,@"category",locationArray,@"location", nil];
  [[SVHTTPClient sharedClient] setSendParametersAsJSON:YES];
  [[SVHTTPClient sharedClient] POST:@"category" parameters:postDictionary completion:^(id response, NSError * error){
     NSLog (@"%@", response);
     if ([(NSArray*) response count]>0 && response != nil) {
       self.currentPlaces = [[NSMutableArray alloc] initWithArray:response copyItems:YES];
       NSMutableArray * array = [NSMutableArray array];
       for (NSDictionary * dict in self.currentPlaces) {
         SGAnnotation * annotation = [[SGAnnotation alloc] init];
         [annotation setTitle:[dict objectForKey:@"name"]];
         NSError *error;
         if (![[GANTracker sharedTracker] trackEvent:@"show_square"
                                              action:@"flip"
                                               label:[dict objectForKey:@"name"]
                                               value:99
                                           withError:&error]) {
           NSLog(@"error in trackEvent");
         }
         CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake ([[dict objectForKey:@"latitude"] floatValue], [[dict objectForKey:@"longitude"] floatValue]);
         [annotation setCoordinate:coordinate];
         [array addObject:annotation];
       }
       [self updateResultCards];
       //adjust map region
       lastAnnotationsMapRegion = [self regionOfAnnotations:array];
       [self.mapView setRegion:lastAnnotationsMapRegion animated:YES];
       [self.mapView addAnnotations:array];
     } else{
       [YRDropdownView showDropdownInView:self.view
          title:@"No Spots Found"
          detail:@"No great spots were found :( Try again!"
          image:[UIImage imageNamed:@"dropdown-alert"]
          animated:YES
          hideAfter:3];
     }
   }];
}

- (void)updateResultCards {
  for (int i = 0; i< [self.currentPlaces count]; i++) {
    NSDictionary * dict = [self.currentPlaces objectAtIndex:i];
    NSLog(@"updating... %@", [dict objectForKey:@"name"]);
    UIButton * currentView = [self.placeResultCardView.subviews objectAtIndex:i];
    for (UIView * subview in [currentView subviews]) {
      [subview  removeFromSuperview];
    }
    UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake(0, 70, 150, 20)];
    [label setText:[dict objectForKey:@"name"]];
    UIFont * font = [UIFont fontWithName:@"Futura-Medium" size:14];
    [label setFont:font];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setTextColor:[UIColor whiteColor]];

    float lat = [[dict objectForKey:@"latitude"] floatValue];
    float lon = [[dict objectForKey:@"longitude"] floatValue];

    NSString * googleMapURL = [NSString stringWithFormat:@"http://cbk0.google.com/cbk?output=thumbnail&w=%d&h=%d&ll=%f,%f", 155, 95,lat, lon];
    [currentView setUserInteractionEnabled:NO];
    [currentView loadImageFromURL:googleMapURL];
    [currentView addSubview:label];
    [currentView setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"gplaypattern.png"]]];
  }
}

- (void)chosePlace:(NSNotification*)notification {
  int choice = [[[notification userInfo] objectForKey:@"choice"] intValue];
  if ([[self.mapView annotations] count] >= choice) {
    SGAnnotation * chosenAnnotation;
    for (SGAnnotation * annotation in [self.mapView annotations]) {
      if ([annotation.title isEqualToString:[[currentPlaces objectAtIndex:choice] objectForKey:@"name"]]) {
        NSError *error;
        if (![[GANTracker sharedTracker] trackEvent:@"show_directions"
                                             action:@"flip"
                                              label:[[currentPlaces objectAtIndex:choice] objectForKey:@"name"]
                                              value:99
                                          withError:&error]) {
          NSLog(@"error in trackEvent");
        }

        [TestFlight passCheckpoint:[NSString stringWithFormat:@"tapped tile for business %@",annotation.title]];
        [[MixpanelAPI sharedAPI] track:[NSString stringWithFormat:@"tapped tile for business %@",annotation.title]];
        [FlurryAnalytics logEvent:[NSString stringWithFormat:@"tapped tile for business %@",annotation.title]];
	chosenAnnotation = annotation;
      }
    }
    if (chosenAnnotation != nil) {
      [self.mapView selectAnnotation:chosenAnnotation animated:YES];
    }
    [self getDirections:choice];
    UIView * currentView = [[[self placeResultCardView] subviews] objectAtIndex:choice];
    //  [self animateView:currentView WithDirection:0];
    [self verticalFlip:currentView WithDuration:1];

    NSLog(@"%@", [[notification userInfo] objectForKey:@"choice"]);
  }
}

- (void)verticalFlip:(UIView*)yourView WithDuration:(int)duration {
  NSDictionary * currentPlaceDict = [[self currentPlaces] objectAtIndex:yourView.tag];
  [UIView animateWithDuration:duration animations:^{
     yourView.layer.transform = CATransform3DMakeRotation (M_PI_2,1.0,0.0,0.0); //flip halfway
   } completion:^(BOOL complete){
     while ([yourView.subviews count] > 0)
       [[yourView.subviews lastObject] removeFromSuperview];  // remove all subviews
     // Add your new views here
     UILabel * nameLabel = [[UILabel alloc] initWithFrame:CGRectMake (0, 115/2, 150, 40)];
     [nameLabel setBackgroundColor:[UIColor clearColor]];
     nameLabel.layer.transform = CATransform3DMakeRotation (M_PI, 1.0f, 0.0f, 0.0f);
     nameLabel.layer.shouldRasterize = TRUE;
     nameLabel.layer.rasterizationScale = [[UIScreen mainScreen] scale];
     [nameLabel setText:[currentPlaceDict objectForKey:@"name"]];
     UIFont * font = [UIFont fontWithName:@"Futura-Medium" size:14];

     [nameLabel setFont:font];
     [nameLabel setLineBreakMode:UILineBreakModeWordWrap];
     [nameLabel setNumberOfLines:2];
     [yourView addSubview:nameLabel];

     if (![[currentPlaceDict objectForKey:@"phone"] isKindOfClass:[NSNull class]]) {
       OHAttributedLabel * phoneLabel = [[OHAttributedLabel alloc] initWithFrame:CGRectMake (0, 0, 150, 20)];
       phoneLabel.automaticallyAddLinksForType = NSTextCheckingTypePhoneNumber;
       phoneLabel.delegate = self;
       [phoneLabel setBackgroundColor:[UIColor clearColor]];
       phoneLabel.layer.transform = CATransform3DMakeRotation (M_PI, 1.0f, 0.0f, 0.0f);
       phoneLabel.layer.shouldRasterize = TRUE;
       phoneLabel.layer.rasterizationScale = [[UIScreen mainScreen] scale];
       [phoneLabel setText:[currentPlaceDict objectForKey:@"phone"]];
       [phoneLabel setFont:font];
       [yourView addSubview:phoneLabel];
     }
     
     UIButton * directionsButton = [[UIButton alloc] initWithFrame:CGRectMake(10, 50, 150, 20)];
     [directionsButton setTitle:@"Directions" forState:UIControlStateNormal];
     directionsButton.tag = yourView.tag;
     [directionsButton addTarget:self action:@selector(getDirections:) forControlEvents:UIControlEventTouchUpInside];
     directionsButton.layer.transform = CATransform3DMakeRotation (M_PI, 1.0f, 0.0f, 0.0f);
     directionsButton.layer.shouldRasterize = TRUE;
     directionsButton.layer.rasterizationScale = [[UIScreen mainScreen] scale];     [yourView addSubview:directionsButton];
     [yourView addSubview:directionsButton];
     [UIView animateWithDuration:duration animations:^{
        yourView.layer.transform = CATransform3DMakeRotation (M_PI,1.0,0.0,0.0); //finish the flip
      } completion:^(BOOL complete){
        // Flip completion code here
      }];
   }];
}

- (void)getDirections:(int)placeInteger {
  if (currentPlaces != nil && [currentPlaces count]>0) {
    NSString * start_latitude = [NSString stringWithFormat:@"%f",[self.mapView userLocation].coordinate.latitude];
    NSString * start_longitude = [NSString stringWithFormat:@"%f",[self.mapView userLocation].coordinate.longitude];
    NSString * destination_latitude = [NSString stringWithFormat:@"%f",[[[currentPlaces objectAtIndex:placeInteger] objectForKey:@"latitude"] floatValue]];
    NSString * destionation_longitude = [NSString stringWithFormat:@"%f",[[[currentPlaces objectAtIndex:placeInteger] objectForKey:@"longitude"] floatValue]];
    NSDictionary * postDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                     start_latitude,@"current_latitude",
                                     start_longitude,@"current_longitude",
                                     destination_latitude,
                                     @"destination_latitude",
                                     destionation_longitude
                                     ,@"destination_longitude", nil];
    [[SVHTTPClient sharedClient] setSendParametersAsJSON:YES];
    [[SVHTTPClient sharedClient] POST:@"location" parameters:postDictionary completion:^(id response, NSError * error){
      NSLog (@"%@", (NSArray*)response);
      
      if ((![response isKindOfClass:[NSData class]]&&![response isKindOfClass:[NSArray class]]) && [[[[[response objectForKey:@"status"] objectForKey:@"Details"] objectAtIndex:0] objectForKey:@"Code"] intValue] != 5) {
        [TestFlight passCheckpoint:[NSString stringWithFormat:@"gotDirections for %@", [[currentPlaces objectAtIndex:placeInteger] objectForKey:@"name"]]];
        self.polylineArray = [[response objectForKey:@"polylines"] componentsSeparatedByString:@";"];
        NSMutableArray * locationArray = [[NSMutableArray alloc] init];
        for (NSString * polyline in polylineArray) {
          NSArray * array = [polyline componentsSeparatedByString:@","];
          [locationArray addObject:[[CLLocation alloc] initWithLatitude:[[array objectAtIndex:0] floatValue] longitude:[[array objectAtIndex:1] floatValue]]];
        }
        
        NVPolylineAnnotation *annotation = [[NVPolylineAnnotation alloc] initWithPoints:locationArray mapView:self.mapView];
        [self.mapView addAnnotation:annotation];
        if (![self coordinateIsVisible:[self.mapView userLocation].coordinate]) {
          MKCoordinateRegion region = [self adjustRegionForAnnotations:[self.mapView  annotations]];
          
          [self.mapView setRegion:region animated:YES];
        }
        
        [UIView animateWithDuration:1 delay:3 options:UIViewAnimationCurveEaseIn animations:^{
          self.placeResultCardView.layer.transform = CATransform3DMakeRotation (M_PI_2,1.0,0.0,0.0); //flip halfway
        } completion:^(BOOL complete){
          
          while ([self.placeResultCardView.subviews count] > 0)
            [[self.placeResultCardView.subviews lastObject] removeFromSuperview];  // remove all subviews
          NSArray * directionsArray = [response objectForKey:@"directions"];
          UITextView * scrollv = [[UITextView alloc] initWithFrame:CGRectMake (0, 0, 320, 200)];
          [scrollv setEditable:NO];
          [scrollv setUserInteractionEnabled:NO];
          NSMutableString * string = [[NSMutableString alloc] init];
          for (NSString * aString in directionsArray) {
            [string appendString:aString];
            [string appendString:@"\n"];
          }
          [self.placeResultCardView setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"gplaypattern.png"]]];
          UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake (0, 0, 320, 200)];
          [label setText:string];
          [label setBackgroundColor:[UIColor clearColor]];
          UIFont * font = [UIFont fontWithName:@"Futura-Medium" size:14];
          [label setFont:font];
          [label setLineBreakMode:UILineBreakModeWordWrap];
          [label setNumberOfLines:0];
          label.layer.shouldRasterize = TRUE;
          label.layer.rasterizationScale = [[UIScreen mainScreen] scale];
          [scrollv addSubview:label];
          scrollv.layer.transform = CATransform3DMakeRotation (M_PI, 1.0f, 0.0f, 0.0f);
          scrollv.layer.shouldRasterize = TRUE;
          scrollv.layer.rasterizationScale = [[UIScreen mainScreen] scale];
          [self.placeResultCardView addSubview:scrollv];
          [UIView animateWithDuration:1 animations:^{
            self.placeResultCardView.layer.transform = CATransform3DMakeRotation (M_PI,1.0,0.0,0.0); //finish the flip
            self.placeResultCardView.layer.shouldRasterize = TRUE;
            self.placeResultCardView.layer.rasterizationScale = [[UIScreen mainScreen] scale];
          } completion:^(BOOL complete){
            // Flip completion code here
          }];
        }];
      }
    }];
  }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {

  if ([annotation isKindOfClass:[NVPolylineAnnotation class]]) {
    return [[NVPolylineAnnotationView alloc] initWithAnnotation:annotation mapView:self.mapView];
  }

  return nil;
}

// Find any polyline annotation and update its region.
- (void)updatePolylineAnnotationView {
  for (NSObject *a in [self.mapView annotations]) {
    if ([a isKindOfClass:[NVPolylineAnnotation class]]) {
      NVPolylineAnnotation *polyline = (NVPolylineAnnotation *)a;

      NSObject *pv = (NSObject *)[self.mapView viewForAnnotation:polyline];
      if ([pv isKindOfClass:[NVPolylineAnnotationView class]]) {
	NVPolylineAnnotationView *polylineView =
	  (NVPolylineAnnotationView *)[self.mapView viewForAnnotation:polyline];

	[polylineView regionChanged];
      }
    }
  }
}

# pragma mark - MKMapViewDelegate

- (void) mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views {
  // fixes that some marker are behind the polyline
  for (int i = 0; i<[views count]; i++) {
    MKAnnotationView *view = [views objectAtIndex:i];
    if ([view isKindOfClass:[NVPolylineAnnotationView class]]) {
      [[view superview] sendSubviewToBack:view];

      /* In iOS version above 4.0 we need to update the polyline view after it
         has been added to the mapview and it ready to be displayed. */
      NSString *reqSysVer = @"4.0";
      NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
      if ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending) {
	[self updatePolylineAnnotationView];
      }
    }
  }
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
  /* In iOS version above 4.0 we need to update the polyline view after a region change */
  NSString *reqSysVer = @"4.0";
  NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
  if ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending) {
    [self updatePolylineAnnotationView];
  }
}

// Returns a adjust region of the map view that contains at least one annotation, with the same center point.
// if there are annotations fall into the current mapview region, it will return the current mapview region,
// otherwise, it will zoom to the region that contain all the annotations.

- (MKCoordinateRegion)adjustRegionForAnnotations:(NSArray*)annotations {
  MKCoordinateRegion adjustRegion = [self minRegionThatHasAnnotations:annotations];
  if ([self hasVisibleAnnotations] && self.mapView.region.span.latitudeDelta < 0.1 && self.mapView.region.span.longitudeDelta < 0.1) {
    return self.mapView.region;
  } else {
    return adjustRegion;
  }
}

- (MKCoordinateRegion)regionThatFitAnnotations:(NSArray*)annotations {
  CLLocationDegrees latDistanceMin = fabs(lastAnnotationsMapRegion.center.latitude - 0.5 * lastAnnotationsMapRegion.span.latitudeDelta - self.mapView.centerCoordinate.latitude);
  CLLocationDegrees latDistanceMax = fabs(lastAnnotationsMapRegion.center.latitude + 0.5 * lastAnnotationsMapRegion.span.latitudeDelta - self.mapView.centerCoordinate.latitude);
  CLLocationDegrees lonDistanceMin = fabs(lastAnnotationsMapRegion.center.longitude - 0.5 * lastAnnotationsMapRegion.span.longitudeDelta - self.mapView.centerCoordinate.longitude);
  CLLocationDegrees lonDistanceMax = fabs(lastAnnotationsMapRegion.center.longitude + 0.5 * lastAnnotationsMapRegion.span.longitudeDelta - self.mapView.centerCoordinate.longitude);

  CLLocationDegrees latDistance = kPinEdgePaddingSpan + ((latDistanceMax > latDistanceMin) ? latDistanceMax : latDistanceMin);
  CLLocationDegrees lonDistance = kPinEdgePaddingSpan + ((lonDistanceMax > lonDistanceMin) ? lonDistanceMax : lonDistanceMin);


  MKCoordinateSpan span;
  span.latitudeDelta =  2 * latDistance;
  span.longitudeDelta = 2 * lonDistance;

  MKCoordinateRegion newRegion = MKCoordinateRegionMake(self.mapView.centerCoordinate, span);
  return newRegion;
}

//return a mapRegion that has at least one annotations
- (MKCoordinateRegion)minRegionThatHasAnnotations:(NSArray*)annotations {
  id<MKAnnotation> minAnnotation = nil;
  if (![annotations count]) {
    return self.mapView.region;
  } else {
    //the first one is nearest onle
    minAnnotation = [annotations objectAtIndex:0];

    MKCoordinateSpan span;
    span.latitudeDelta = 2 * fabs(minAnnotation.coordinate.latitude - self.mapView.centerCoordinate.latitude) + kPinEdgePaddingSpan;
    span.longitudeDelta = 2 * fabs(minAnnotation.coordinate.longitude  - self.mapView.centerCoordinate.longitude) + kPinEdgePaddingSpan;
    MKCoordinateRegion newRegion = MKCoordinateRegionMake(self.mapView.centerCoordinate, span);
    return [self.mapView regionThatFits:newRegion];
  }
}

- (MKCoordinateRegion)regionOfAnnotations:(NSArray*)annotations {

  CLLocationDegrees maxLat = -90;
  CLLocationDegrees maxLon = -180;
  CLLocationDegrees minLat = 90;
  CLLocationDegrees minLon = 180;
  for (id<MKAnnotation> annotation in annotations) {
    if (annotation.coordinate.latitude > maxLat) {
      maxLat = annotation.coordinate.latitude;
    }
    if (annotation.coordinate.latitude < minLat) {
      minLat = annotation.coordinate.latitude;
    }
    if (annotation.coordinate.longitude > maxLon) {
      maxLon = annotation.coordinate.longitude;
    }
    if (annotation.coordinate.longitude < minLon) {
      minLon = annotation.coordinate.longitude;
    }
  }
  if ([annotations count] > 0) {
    CLLocationCoordinate2D newCenter;
    newCenter.latitude = 0.5 *(minLat + maxLat);
    newCenter.longitude = 0.5 * (minLon + maxLon);
    return MKCoordinateRegionMake(newCenter, MKCoordinateSpanMake(fabs(minLat - maxLat), fabs(minLon - maxLon)));
  } else {
    return self.mapView.region;
  }
}

//return true if  the region contains the coorinate
- (BOOL)mapRegion:(MKCoordinateRegion)mapRegion containsCoordinate:(CLLocationCoordinate2D)coordinate {
  return ((fabs(coordinate.latitude - mapRegion.center.latitude) <= 0.5 * mapRegion.span.latitudeDelta) &&
          (fabs(coordinate.longitude - mapRegion.center.longitude) <= 0.5 * mapRegion.span.longitudeDelta));
}

//current mapview has visible annotations
- (BOOL)hasVisibleAnnotations {

  for (id<MKAnnotation> annotation in self.mapView.annotations) {
    if ([self coordinateIsVisible:annotation.coordinate]) {

      //we found a visible annotation, just return;
      return YES;
    }
  }
  return NO;
}

- (BOOL)coordinateIsVisible:(CLLocationCoordinate2D)coordinate {
  CGPoint annPoint = [self.mapView convertCoordinate:coordinate
                      toPointToView:self.mapView];

  return (annPoint.x > 0.0 && annPoint.y > 0.0 &&
          annPoint.x < self.mapView.frame.size.width &&
          annPoint.y < self.mapView.frame.size.height);
}

- (void)setAnchorPoint:(CGPoint)anchorPoint forView:(UIView *)view
{
  CGPoint newPoint = CGPointMake(view.bounds.size.width * anchorPoint.x, view.bounds.size.height * anchorPoint.y);
  CGPoint oldPoint = CGPointMake(view.bounds.size.width * view.layer.anchorPoint.x, view.bounds.size.height * view.layer.anchorPoint.y);

  newPoint = CGPointApplyAffineTransform(newPoint, view.transform);
  oldPoint = CGPointApplyAffineTransform(oldPoint, view.transform);

  CGPoint position = view.layer.position;

  position.x -= oldPoint.x;
  position.x += newPoint.x;

  position.y -= oldPoint.y;
  position.y += newPoint.y;

  view.layer.position = position;
  view.layer.anchorPoint = anchorPoint;
}

- (void)animateView:(UIView *)view WithDirection:(int)direction
{
  CALayer *layer = view.layer;
  CATransform3D initialTransform = view.layer.transform;
  initialTransform.m34 = 1.0 / -1000;

  [self setAnchorPoint:CGPointMake(-0.3, 0.5) forView:view];


  [UIView beginAnimations:@"Scale" context:nil];
  [UIView setAnimationDuration:1];
  [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
  layer.transform = initialTransform;


  CATransform3D rotationAndPerspectiveTransform = view.layer.transform;
  if (direction == 1) {
    rotationAndPerspectiveTransform = CATransform3DRotate(rotationAndPerspectiveTransform, M_PI, 0, 0, 0);
  } else if(direction == 0) {
    rotationAndPerspectiveTransform = CATransform3DRotate(rotationAndPerspectiveTransform, M_PI, view.bounds.size.width, 0, 0);
  }

  layer.transform = rotationAndPerspectiveTransform;

  [UIView setAnimationDelegate:self];
  [UIView commitAnimations];
}

-(BOOL)attributedLabel:(OHAttributedLabel *)attributedLabel shouldFollowLink:(NSTextCheckingResult *)linkInfo {
	[attributedLabel setNeedsDisplay];

		switch (linkInfo.resultType) {
			case NSTextCheckingTypeLink: // use default behavior
				break;
			case NSTextCheckingTypeAddress:
				[self displayAlert:@"Address" message:[linkInfo.addressComponents description]];
				break;

			case NSTextCheckingTypePhoneNumber:
				[self displayAlert:@"Phone Number" message:linkInfo.phoneNumber];
				break;
			default:
				[self displayAlert:@"Unknown link type" message:[NSString stringWithFormat:@"You typed on an unknown link type (NSTextCheckingType %d)",linkInfo.resultType]];
				break;
		}

		return YES;
}

-(void) displayAlert:(NSString*) title message:(NSString*) message {
	UIAlertView* alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
	[alert show];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  // Do any additional setup after loading the view.
}

- (void)viewDidUnload
{
  [self setMapView:nil];
  [self setPlaceResultCardView:nil];
  [super viewDidUnload];
  // Release any retained subviews of the main view.
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
  switch (buttonIndex) {
    case 1:
    {
      NSString * trimmedString = [[[[alertView.message stringByReplacingOccurrencesOfString:@"(" withString:@""] stringByReplacingOccurrencesOfString:@")" withString:@""] stringByReplacingOccurrencesOfString:@" " withString:@""] stringByReplacingOccurrencesOfString:@"-" withString:@""];
      NSString *phoneURLString = [NSString stringWithFormat:@"tel:%@", trimmedString];
      NSURL *phoneURL = [NSURL URLWithString:phoneURLString];
      [[UIApplication sharedApplication] openURL:phoneURL];
    }
      break;
      
    default:
      break;
  }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
