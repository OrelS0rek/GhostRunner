//
//  FriendManager.swift
//  GhostRunner
//
//  Created by Admin on 26/03/2026.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
internal import Combine

class FriendManager: ObservableObject {
    static let shared = FriendManager()
    private let db = Firestore.firestore()

    @Published var friends: [UserProfile] = []
    @Published var friendRequests: [UserProfile] = []
    @Published var searchResults: [UserProfile] = []
    @Published var isSearching: Bool = false
    @Published var friendsFeed: [FeedRun] = []

    private init() {}

    // MARK: - חיפוש משתמשים על פי שם משתמש
    func searchUsers(query: String) {
        // בדיקה שהשאילתה לא ריקה ושקיים משתמש מחובר
        guard !query.isEmpty,
              let currentUID = Auth.auth().currentUser?.uid else {
            searchResults = []
            return
        }

        isSearching = true

        // על פי שיטות של כתיבת שאילתות של פיירבייס, האפליקציה תציג למשתמש את המשתמשים ששמם מתחיל במה שכתבנו
        let end = query + "\u{f8ff}"
        db.collection("users")
            .whereField("displayName", isGreaterThanOrEqualTo: query)
            .whereField("displayName", isLessThanOrEqualTo: end)
            .limit(to: 20)
            .getDocuments { snapshot, _ in
                DispatchQueue.main.async {              // חזרה לתהליכון הראשי
                    self.isSearching = false
                    self.searchResults = snapshot?.documents
                        .compactMap { UserProfile(from: $0.data(), id: $0.documentID) }
                        .filter { $0.id != currentUID } // להוסיף פילטר שלא אוכל לחפש את המשתמש של עצמי
                    ?? []
                }
            }
    }

    // MARK: - שליחת בקשת חברות
    func sendFriendRequest(to user: UserProfile, completion: @escaping (Bool) -> Void) {
        // בדיקה האם מישהו מחובר
        guard let currentUID = Auth.auth().currentUser?.uid else { return }

        // רשימת מסמך בקשת חברות בתוך התת-קולקציה של בקשות חברות בתוך הקולקציה של המשתמשים במסד הנתונים
        db.collection("users").document(user.id)
            .collection("friendRequests")
            .document(currentUID)
            .setData(["from": currentUID, "timestamp": Timestamp(date: Date())]) { error in
                completion(error == nil)
            }
    }

    // MARK: - לקיחת בקשות חברות
    func fetchFriendRequests() {
        // בדיקה האם מישהו מחובר
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // קריאה מהתת-קולקציה של בקשות חברות בתוך הקולקציה של המשתמשים במסד הנתונים
        db.collection("users").document(uid)
            .collection("friendRequests")
            //הוספת מאזין בזמן אמת לבקשות חברות נכנסות למשתמש המחובר
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let uids = docs.map { $0.documentID }
                //משיכת פרטי הפרופיל של מי שמבקש חברות
                self.fetchUserProfiles(uids: uids) { profiles in
                    //חזרה לתהליכון המרכזי עבור עדכון משתנים שמעדכנים את ממשק המשתמש
                    DispatchQueue.main.async {
                        self.friendRequests = profiles
                    }
                }
            }
    }

    // MARK: - אישור בקשת חברות
    func acceptFriendRequest(from user: UserProfile, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let batch = db.batch() //ביצוע של הפעולות כפעולות אטומיות

        // שמירת משתנה עבור מסמך החבר עבור כל אחד מהמשתמשים, ושל הבקה (כדי שנוכל למחוק אותה)
        let myFriendRef = db.collection("users").document(uid)
            .collection("friends").document(user.id)
        let theirFriendRef = db.collection("users").document(user.id)
            .collection("friends").document(uid)
        let requestRef = db.collection("users").document(uid)
            .collection("friendRequests").document(user.id)
        
        batch.setData(["uid": user.id, "since": Timestamp(date: Date())], forDocument: myFriendRef) //הוספת החבר בקולקציה של המשתמש
        batch.setData(["uid": uid,     "since": Timestamp(date: Date())], forDocument: theirFriendRef) //הוספת המשתמש בקולקציה של החבר
        batch.deleteDocument(requestRef) //מחיקת המסמך של בקשת חברות כיוון שטיפלנו בה

        batch.commit { error in
            DispatchQueue.main.async {
                //חזרה לתהליכון מרכזי לטיפול בתגובה שקיבלנו מהcallback
                completion(error == nil)
                if error == nil {
                    self.fetchFriends()
                }
            }
        }
    }

    // MARK: - דחיית בקשת חברות
    func declineFriendRequest(from user: UserProfile) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        //מחיקת מסמך בקשת החברות מתוך מסד הנתונים
        db.collection("users").document(uid)
            .collection("friendRequests")
            .document(user.id)
            .delete()
    }

    // MARK: - משיכת רשימה של חברים
    func fetchFriends() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(uid)
            .collection("friends")
            //מאזין לשינויים בקולקציות כך שיהיה רענון צמידי ומשיכה כאשר יש שינויים
            .addSnapshotListener { snapshot, _ in
                let uids = snapshot?.documents.map { $0.documentID } ?? []
                self.fetchUserProfiles(uids: uids) { profiles in
                    DispatchQueue.main.async {
                        //עדכון המשתנים שצריך בתהליכון המרכזי עבור עדכון ממשק המשתמש
                        self.friends = profiles
                        self.fetchFriendsFeed(friendUIDs: uids)
                    }
                }
            }
    }

    // MARK: - משיכת ריצות של חברים
    func fetchFriendsFeed(friendUIDs: [String]) {
        guard let myUID = Auth.auth().currentUser?.uid else { return }

        //יצירת רשימה של כל החברים
        var allUIDs = friendUIDs
        if !allUIDs.contains(myUID) { //הוספה של עצמנו כדי שנוכל לראות את הריצות של עצמנו במסך הבית
            allUIDs.append(myUID)
        }

        guard !allUIDs.isEmpty else { //בדיקה שהרשימה אינה ריקה
            DispatchQueue.main.async { self.friendsFeed = [] } //עדכון בתהליכון המרכזי של הפיד כדי לעדכן את ממשק המשתמש
            return
        }
        
        //פיצול רשימת המשתמשים לקבוצות של 10 כדי להתמודד עם החוקים שהצבנו בפיירבייס
        let chunks = stride(from: 0, to: allUIDs.count, by: 10).map {
            Array(allUIDs[$0..<min($0 + 10, allUIDs.count)])
        }

        var allRuns: [FeedRun] = []     //אתחול רשימה של הפיד של הריצות
        let group = DispatchGroup()     //סנכרון בין מספר משימות אסינכרוניות

        for chunk in chunks {
            group.enter()                               //תחילת משימה אסינכרונית בתהליכון נפרד
            db.collection("runs")
                .whereField("userId", in: chunk)        //סינון הריצות
                .order(by: "timestamp", descending: true)
                .limit(to: 20)
                .getDocuments { snapshot, _ in          //בקשת המסמכים של הריצות ששדה המשתמש שלהן נמצא ברשימה שלנו
                    let runs = snapshot?.documents
                        .compactMap { FeedRun(from: $0.data(), id: $0.documentID) } ?? []
                    allRuns.append(contentsOf: runs)    //הוספה לרשימה של הפידים שיצרנו
                    group.leave()
                }
        }

        group.notify(queue: .main) {
            //מיון של כל הריצות שהתקבלו לפי זמן
            self.friendsFeed = allRuns.sorted { $0.timestamp > $1.timestamp }
        }
    }

    // MARK: - בדיקת סטטוס חברות
    func friendshipStatus(with uid: String, completion: @escaping (FriendshipStatus) -> Void) {
        guard let myUID = Auth.auth().currentUser?.uid else { return }
        //קריאת המסמך של המשתמש שנרצה לבדוק
        db.collection("users").document(myUID)
            .collection("friends").document(uid)
            .getDocument { snapshot, _ in
                if snapshot?.exists == true {   //האם המסמך שביקשנו קיים? אם כן נקרא לבלוק טיפול עם ערך friends
                    completion(.friends)
                    return
                }
                //קריאת מסמך הבקשות חברות
                self.db.collection("users").document(uid)
                    .collection("friendRequests").document(myUID)
                    .getDocument { snapshot, _ in
                        completion(snapshot?.exists == true ? .requestSent : .none) //בבלוק טיפול, במידה והמסמך שביקשנו קיים נשמור שהמשתמש שלח בקשת חברות, במידה ולא נשמור שהוא לא קשור אלינו
                    }
            }
    }

    // MARK: - Helper: batch fetch user profiles by UIDs
    private func fetchUserProfiles(uids: [String], completion: @escaping ([UserProfile]) -> Void) {
        guard !uids.isEmpty else { completion([]); return }
        
        var profiles: [UserProfile] = []            //אתחול רשימת פרופילים
        let group = DispatchGroup()                 //יצירת קבוצה לסנכרון של משימות אסינכרוניות (קריאות רשת)

        for uid in uids {
            group.enter()                           // התחלה של העבודה האסינכרונית
            db.collection("users").document(uid).getDocument { snapshot, _ in
                if let data = snapshot?.data(),
                   let profile = UserProfile(from: data, id: uid) {
                    profiles.append(profile) //הוספת הפרופיל לרשימה
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(profiles) }
    }
}

// MARK: - מודלים

//מבנה של פרופיל משתמש
struct UserProfile: Identifiable {
    let id: String
    let displayName: String
    let email: String
    let profileImageURL: String
    let totalRuns: Int
    let totalKm: Double
    
    //ערכי ברירת מחדל
    init?(from data: [String: Any], id: String) {
        self.id              = id
        self.displayName     = data["displayName"] as? String ?? ""
        self.email           = data["email"] as? String ?? ""
        self.profileImageURL = data["profileImageURL"] as? String ?? ""
        self.totalRuns       = data["totalRuns"] as? Int ?? 0
        self.totalKm         = data["totalKm"] as? Double ?? 0.0
    }
}

//מבנה פיד של ריצה
struct FeedRun: Identifiable {
    let id: String
    let userId: String
    let title: String
    let notes: String
    let distanceKm: Double
    let durationSeconds: Double
    let avgPaceSecPerKm: Double
    let photoURLs: [String]
    let timestamp: Date
    let points: Int
    
    //ערכי ברירת מחדל
    init?(from data: [String: Any], id: String) {
        self.id              = id
        self.userId          = data["userId"] as? String ?? ""
        self.title           = data["title"] as? String ?? "Untitled Run"
        self.notes           = data["notes"] as? String ?? ""
        self.distanceKm      = data["distanceKm"] as? Double ?? 0
        self.durationSeconds = data["durationSeconds"] as? Double ?? 0
        self.avgPaceSecPerKm = data["avgPaceSecPerKm"] as? Double ?? 0
        self.photoURLs       = data["photoURLs"] as? [String] ?? []
        self.points          = data["points"] as? Int ?? 0
        let ts               = data["timestamp"] as? Timestamp
        self.timestamp       = ts?.dateValue() ?? Date()
    }
}
//אנומרציה שמייצגת את המצבים של סטטוס חברות
enum FriendshipStatus {
    case none, requestSent, friends
}
