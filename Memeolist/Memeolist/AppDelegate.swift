import AGSAuth
import AGSSync
import Alamofire
import IQKeyboardManagerSwift
import UIKit


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var profile: ProfileDetails!

    // Redirects the user to the login screen
    func requireLogin() -> Bool {
        let rootViewController = LoginViewController()
        window?.rootViewController = UINavigationController(rootViewController: rootViewController)
        window?.makeKeyAndVisible()
        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        IQKeyboardManager.shared.enable = true

        // create the authentication config
        let authenticationConfig = AuthenticationConfig(redirectURL: "memeolist://callback")
        do {
            try AgsAuth.instance.configure(authConfig: authenticationConfig)
            if let transport = AgsSync.instance.transport {
                transport.headerProvider = AgsAuth.instance.getAuthHeaderProvider()
            }

            guard let _ = try! AgsAuth.instance.currentUser() else {
                return requireLogin()
            }
        } catch AgsAuth.Errors.noServiceConfigurationFound {
            print("No Auth configuration found.")
            return false
        } catch {
            print("Error authenticating user.")
            return requireLogin()
        }
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
        do {
            return try AgsAuth.instance.resumeAuth(url: url as URL)
        } catch AgsAuth.Errors.serviceNotConfigured {
            print("AeroGear auth service is not configured")
        } catch {
            fatalError("Unexpected error: \(error).")
        }
        return false
    }
    
    public func createOrRetrieveProfile(user: User) {
        AgsSync.instance.client?.fetch(query: ProfileQuery(email: user.email!), cachePolicy: .fetchIgnoringCacheData) { result, error in
            if let error = error {
                NSLog("Error while fetching query: \(error.localizedDescription)")
                let alert = UIAlertController(title: "Error", message: "Failed to fetch profile", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.window?.rootViewController?.present(alert, animated: true, completion: nil)
                return
            }
            
            let profiles = result?.data?.profile
            if(profiles != nil && (profiles?.count)! > 0) {
                let profile = profiles![0]?.fragments.profileDetails
                self.profile = profile
            } else {
                self.createProfile(user: user)
            }
        }
    }
    
    public func createProfile(user: User) {
        AgsSync.instance.client?.perform(mutation: CreateProfileMutation(email: user.email!, displayname: user.fullName!, pictureurl: "https://randomuser.me/api/portraits/lego/1.jpg")) { result, error in
            if let profile = result?.data?.createProfile.fragments.profileDetails {
                self.profile = profile
            } else {
                let alert = UIAlertController(title: "Error", message: "Failed to create profile", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.window?.rootViewController?.present(alert, animated: true)
            }
            return
        }
    }
    
}
