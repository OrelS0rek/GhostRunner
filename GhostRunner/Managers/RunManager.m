//
//  RunManager.m
//  GhostRunner
//
//  Created by Admin on 26/03/2026.
//

#import "RunManager.h"

@interface RunManager ()
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *route;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, assign) double totalDistanceKm;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong) CLLocation *lastLocation;
@end

@implementation RunManager
// תבנית עיצוב סינגלטון - מחלקה סטטית שמתקשרים ישירות איתה ולא עם מופע ספציפי שלה.
+ (instancetype)sharedManager {
    static RunManager *shared = nil;
    static dispatch_once_t onceToken;           //טוקן מיוחד של השפה שקובע שהקוד שמופיע בבלוק שאחרי ירוץ רק פעם אחת
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];           //אתחול המחלקה - ירוץ רק פעם אחת בגלל הבלוק וכך יוודא שכל האפליקציה תתקשר עם המחלקה עצמה ולא עם מופע שלה (סינגלטון)
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _route = [NSMutableArray array];
        _totalDistanceKm = 0.0;
        _isRunning = NO;
    }
    return self;
}

//התחלת ריצה ושינוי המשתנים שצריך
- (void)startRun {
    _route = [NSMutableArray array];
    _totalDistanceKm = 0.0;
    _lastLocation = nil;
    _isRunning = YES;
    _startTime = [NSDate date];
}

//הפסקת הריצה
- (void)stopRunWithCompletion:(void(^)(NSDictionary *runData))completion {
    _isRunning = NO;

    NSTimeInterval duration = [self currentDurationSeconds];
    double pace = [self currentPaceSecPerKm];

    NSDictionary *runData = @{
        @"distanceKm":        @(_totalDistanceKm),
        @"durationSeconds":   @(duration),
        @"avgPaceSecPerKm":   @(pace),
        @"route":             [_route copy],
        @"timestamp":         [NSDate date]
    };

    if (completion) {
        completion(runData);
    }
}

- (void)addCoordinate:(CLLocationCoordinate2D)coord {
    if (!_isRunning) return;

    CLLocation *newLocation = [[CLLocation alloc] initWithLatitude:coord.latitude
                                                         longitude:coord.longitude];
    if (_lastLocation) {
        double deltaMetres = [newLocation distanceFromLocation:_lastLocation];          //דלטה - השינוי במטרים
        double deltaKm = deltaMetres / 1000.0;                                          //דלטה - השינוי בקילומטרים
        if (deltaMetres > 1.0 && deltaKm < 0.5) {                                       //סינון כך שעדכון של שינוי לא יהיה גדול מדי במקרה של שיבוש gps - קפיצה לא תקרא על ידי האפליקציה
            _totalDistanceKm += deltaKm;
        }
    }

    _lastLocation = newLocation;

    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:_startTime];
    //שמירת אוביקט מסלול ריצה - מיקום בקואורדינטות לפי זמן כך שיהיה ניתן לשחזר עבור רוח
    [_route addObject:@{
        @"lat":     @(coord.latitude),
        @"lng":     @(coord.longitude),
        @"elapsed": @(elapsed)   //שניות מתחילת הריצה
    }];
}
//מרחק בקילומטרים
- (double)currentDistanceKm {
    return _totalDistanceKm;
}
//קצב בשניות לקילומטר
- (double)currentPaceSecPerKm {
    NSTimeInterval elapsed = [self currentDurationSeconds];
    if (_totalDistanceKm < 0.01) return 0;
    return elapsed / _totalDistanceKm;
}
//זמן בשניות
- (NSTimeInterval)currentDurationSeconds {
    if (!_startTime) return 0;
    return [[NSDate date] timeIntervalSinceDate:_startTime];
}

//העתק של המסלול שהוקלט
- (NSArray<NSDictionary *> *)recordedRoute {
    return [_route copy];
}

@end
