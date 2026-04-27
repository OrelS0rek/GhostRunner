//
//  AuthManager.h
//  GhostRunner
//
//  Created by Admin on 09/02/2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AuthManager : NSObject
+ (instancetype)sharedManager;                      //+ מוודא שזו פונקציה סטטית השייכת למחלקה ולא למופע שלה.


//פונקציה המנהלת את החיבור מול firebase
// הפונציקה מקבלת מייל וסיסמא, מחזירה בלוק עם תשובה משרת הפיירבייס שניתן לטפל בו בסיום הפונקציה
- (void)loginWithEmail:(NSString *)email
        password:(NSString *)password
           completion:(void(^)(BOOL success, NSString *error))completion;
// פונקציה המנהלת את הרישום מול firebase
// הפונקציה מקבלת מייל וסיסמא, ומחזירה בלוק עם תשובה שרת הפיירבייס שניתן לטפל בו בסיום הפונקציה
- (void)registerWithEmail:(NSString *)email
                 password:(NSString *)password
               completion:(void(^)(BOOL success, NSString *error))completion;
@end

NS_ASSUME_NONNULL_END
