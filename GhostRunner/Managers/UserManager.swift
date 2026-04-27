//
//  UserManager.swift
//  GhostRunner
//
//  Created by Admin on 26/03/2026.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import UIKit
internal import Combine

//מחלקה האחראית על כל הפעולות עבור משתמש - observable כדי שמחלקות אחרות יוכלו לקבל עדכונים על אירועים ושינויים במחלקה הזאת בצורה אוטומטית
class UserManager: ObservableObject {
    static let shared = UserManager()               //מופע יחיד (סינגלטון) משותף איתו כולם יתקשרו
    private let db = Firestore.firestore()          //אתחול תקשורת עם מסד הנתונים
    private let storage = Storage.storage()

    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var profileImageURL: String = ""
    @Published var totalRuns: Int = 0
    @Published var totalKm: Double = 0.0
    @Published var isLoading: Bool = false

    private var listener: ListenerRegistration?         //משתנה עבור מחלקות אחרות שצריכות להאזין לאירועים פה בדומה לאירוע בשפה c#

    private init() {}
    
    //יצירת פרופיל
    func createUserProfile(uid: String, fullName: String, email: String) {
        let data: [String: Any] = [
            "displayName": fullName,
            "email": email,
            "totalRuns": 0,
            "totalKm": 0.0,
            "profileImageURL": "",
            "createdAt": Timestamp(date: Date())
        ]
        //כתיבת המידע לקולקציה של משתמשים במסד הנתונים
        db.collection("users").document(uid).setData(data) { error in
            if let error = error {
                print("Error creating profile: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    //עדכון משתנים בתהליכון הראשי עבור עדכון ממשק המשתמש
                    self.displayName = fullName
                    self.email = email
                }
            }
        }
    }
    //משיכת הפרופיל ממסד הנתונים
    func fetchProfile() {
        // בדיקה שהמשתמש הנוכחי מחובר
        guard let uid = Auth.auth().currentUser?.uid,
              let email = Auth.auth().currentUser?.email else { return }
        isLoading = true
        listener?.remove()

        let ref = db.collection("users").document(uid)
        //הוספת מאזין לשינויים במסמך הפרופיל
        listener = ref.addSnapshotListener { snapshot, error in
            DispatchQueue.main.async {
                self.isLoading = false

                // אם המסמך לא קיים מראש - ליצור עכשיו
                if snapshot?.exists == false {
                    let data: [String: Any] = [
                        "displayName": email.components(separatedBy: "@").first ?? "Runner",    //לקיחת החלק הראשון מהמייל עבור שם המשתמש
                        "email": email,
                        "totalRuns": 0,
                        "totalKm": 0.0,
                        "profileImageURL": "",
                        "createdAt": Timestamp(date: Date())
                    ]
                    ref.setData(data)
                    self.displayName = data["displayName"] as? String ?? ""
                    self.email = email
                    return
                }

                guard let data = snapshot?.data() else { return }
                self.displayName       = data["displayName"] as? String ?? ""
                self.email             = data["email"] as? String ?? ""
                self.profileImageURL   = data["profileImageURL"] as? String ?? ""
                self.totalRuns         = data["totalRuns"] as? Int ?? 0
                self.totalKm           = data["totalKm"] as? Double ?? 0.0
            }
        }
    }

    //העלאת תמונת פרופיל
    func uploadProfileImage(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid,
              let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(false)
            return
        }
        
        //יצירת הפנייה ל firestore storage בו נשמור את הקישור לתמונה
        let ref = storage.reference().child("profileImages/\(uid).jpg")
        //העלאת התמונה
        ref.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Upload error: \(error.localizedDescription)")
                completion(false)
                return
            }
            ref.downloadURL { url, _ in
                guard let url = url else { completion(false); return }
                //שמירת קישור למיקום התמונה במסד הנתונים
                self.db.collection("users").document(uid).updateData([
                    "profileImageURL": url.absoluteString
                ]) { error in
                    DispatchQueue.main.async {
                        if error == nil {
                            self.profileImageURL = url.absoluteString
                            completion(true)
                        } else {
                            completion(false)
                        }
                    }
                }
            }
        }
    }

    func incrementStats(distanceKm: Double) {
        //הגדלת ועדכון הסטטיסטיקות של המשתמש במסד הנתונים, בגלל מאזינים יעדכן אוטומטית את המסכים הנדרשים
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).updateData([
            "totalRuns": FieldValue.increment(Int64(1)),
            "totalKm":   FieldValue.increment(distanceKm)
        ])
    }
}
