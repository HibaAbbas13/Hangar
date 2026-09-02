import Foundation
import FirebaseFirestore

final class DatabaseService {
    static let shared = DatabaseService()

    let db: Firestore

    private init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func userDoc(_ userId: String) -> DocumentReference {
        db.collection(Constants.Firestore.users).document(userId)
    }

    func decks(_ userId: String) -> CollectionReference {
        userDoc(userId).collection(Constants.Firestore.decks)
    }

    func deck(_ userId: String, _ deckId: String) -> DocumentReference {
        decks(userId).document(deckId)
    }

    func buttons(_ userId: String, _ deckId: String) -> CollectionReference {
        deck(userId, deckId).collection(Constants.Firestore.buttons)
    }

    func button(_ userId: String, _ deckId: String, _ buttonId: String) -> DocumentReference {
        buttons(userId, deckId).document(buttonId)
    }

    func activity(_ userId: String) -> CollectionReference {
        userDoc(userId).collection(Constants.Firestore.activity)
    }

    func members(_ userId: String, _ deckId: String) -> CollectionReference {
        deck(userId, deckId).collection(Constants.Firestore.members)
    }

    func profiles(_ userId: String, _ deckId: String) -> CollectionReference {
        deck(userId, deckId).collection(Constants.Firestore.profiles)
    }

    func sharedDecks(_ userId: String) -> CollectionReference {
        userDoc(userId).collection(Constants.Firestore.sharedDecks)
    }

    func invites(_ userId: String) -> CollectionReference {
        userDoc(userId).collection(Constants.Firestore.invites)
    }

    func inviteCodes() -> CollectionReference {
        db.collection(Constants.Firestore.inviteCodes)
    }
}
