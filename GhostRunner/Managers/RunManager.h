//
//  RunManager.h
//  GhostRunner
//
//  Created by Admin on 26/03/2026.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RunManager : NSObject <CLLocationManagerDelegate>

+ (instancetype)sharedManager;              //מתודת מחלקה, מופע singleton

// שליטה על ריצה אחת
- (void)startRun;
- (void)stopRunWithCompletion:(void(^)(NSDictionary *runData))completion;

// נקרא בכל פעם שהספריה cllocation שולחת קואורדינטה חדשה
- (void)addCoordinate:(CLLocationCoordinate2D)coord;

// סטטיסטיקות בלייב שנשלחות למסך runview כל כמה שניות בעזרת טיימר
- (double)currentDistanceKm;            // מרחק בקמ
- (double)currentPaceSecPerKm;          // קצב בשניות לקמ
- (NSTimeInterval)currentDurationSeconds;       // זמן בשניות

// המסלול מלא מוקלט כמילון של זמן - קואורדינטה
- (NSArray<NSDictionary *> *)recordedRoute;

@end

NS_ASSUME_NONNULL_END
