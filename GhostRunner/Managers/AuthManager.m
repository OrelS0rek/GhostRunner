//
//  AuthManager.m
//  GhostRunner
//
//  Created by Admin on 09/02/2026.
//

#import "AuthManager.h"
@import FirebaseAuth;
@import FirebaseCore;

@implementation AuthManager
// תבנית עיצוב סינגלטון - מחלקה סטטית שמתקשרים ישירות איתה ולא עם מופע ספציפי שלה.
+ (instancetype)sharedManager {                 //+  פונקציית מחלקה
    static AuthManager *shared = nil;
    static dispatch_once_t onceToken;           //טוקן מיוחד של השפה, שדואג שהבלוק הבא ירוץ רק פעם אחת בחיי האפליקציה
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];           // מקצים זיכרון ומאתחלים את המחלקה למשתנה הסטטי shared
    });
    return shared;
}

// פונקצייה המנהלת את החיבור מול שרת הfirebase
//הפונקצייה מקבלת מייל וסיסמא, ובהתאם לתשובה מהשרת מחזירה בלוק שמטופל אסינכרונית בסיום הפונקציה
- (void)loginWithEmail:(NSString *)email password:(NSString *)password completion:(void(^)(BOOL success, NSString *error))completion {
    // קריאה לפונקצייה של גוגל מתוך הספרייה של פיירבייס signInWithEmail
    [[FIRAuth auth] signInWithEmail:email password:password completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
        if (error) {
            completion(NO, error.localizedDescription);     //במידה ויש שגיאה , מדפיסים הודעת שגיאה שקיבלנו מfirebase
        } else {
            completion(YES, nil);                           //מחזירים למי שקרא לפונקציה תגובת הצלחה
        }
    }];
}


// פונקצייה המנהלת את הרישום מול שרת הfirebase
//הפונקצייה מקבלת מייל וסיסמא, ובהתאם לתשובה מהשרת מחזירה בלוק שמטופל אסינכרונית בסיום הפונקציה

- (void)registerWithEmail:(NSString *)email password:(NSString *)password completion:(void(^)(BOOL success, NSString *error))completion {
    //קריאה לפונקצייה של גוגל מתוף הספרייה של פיירבייס createUserWithEmail
    [[FIRAuth auth] createUserWithEmail:email password:password completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
        if (error) {
            completion(NO, error.localizedDescription);     //במידה ויש שגיאה, מדפיסים הודעת שגיאה שקיבלנו מהשרת
        } else {
            completion(YES, nil);                           // מחזירים למי שקרא לפונקצייה תגובת הצלחה
        }
    }];
}

@end
