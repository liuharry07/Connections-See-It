//
//  ContentView.swift
//  Connections Helper
//
//  Created by Harry Liu on 12/26/23.
//

import SwiftUI
import WebKit
import SwiftSoup

/*
 
 WebData Class:
 
 This object class acts as a buffer between WebKit/UIKit and SwiftUI. Since the two frameworks are inherently different, the variables of the imperative framework of UIKit must be passed to the declarative framework of SwiftUI. Observable Objects are perfect for this function because they notify views when there is a change in the data they are observing, allowing us to know when the word retrieval is complete.
 
 */
 
class WebData: ObservableObject {
    @Published var isFinished: Bool = false
    @Published var words: [String] = []
}

/*
 
 WordRetrieverView Structure:
 
 This structure handles all the components of retrieving the daily words from the New York Times webpage. This structure implements the UIViewRepresentable protocol to open the New York Times Connections webpage through UIKit, allowing for the retrieval of HTML data.
 
 */

struct WordRetrieverView: UIViewRepresentable {
    @ObservedObject var wordsObject: WebData
    
    /*
     
     Coordinator Class:
     
     Since the UIViewRepresentable protocol functions in a UIKit view, a coordinator is created to be able to communicate and transfer information between this structure and the rest of the SwiftUI code. When the WordRetrieverView structure is called, a coordinator is automatically created, which implements the WKNavigationDelegate delegate object, tracking the progress of the request to access the HTML data of the website.
     
     */
    
    class Coordinator: NSObject, WKNavigationDelegate {
        
        var parent: WordRetrieverView
        @ObservedObject var wordsObject: WebData
        
        init(parent: WordRetrieverView, wordsObject: WebData) {
            self.parent = parent
            self.wordsObject = wordsObject
        }
        
        /*
         
         webView Function:
         
         This function is built-in to the WKNavigationDelegate protocol that tells the delegate when the webView finishes loading. Once the website is finished loading, the full HTML data of the website can be accessed, including dynamically-loaded content in JavaScript, which is the part that we need to access in order to get the daily words.
         
         */
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.getWords(webView: webView) { success, words in
                if success {
                    self.wordsObject.words = words
                    self.wordsObject.isFinished = true
                    //changes values of object, this object goes to the parent function
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        //automatically called by WebKit to create a coordinator object
        
        return Coordinator(parent: self, wordsObject: wordsObject)
        //second parameter is created observable object that allows info to go back to main SwiftUI code
    }
    
    /*
     
     makeUiView Function:
     
     This method is a required UIViewRepresentable function that is implemented to create the web view. This configures its initial state, which we use to grab the HTML from the website.
     
     */
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let url = URL(string: "https://www.nytimes.com/games/connections")!
        let request = URLRequest(url: url)
        webView.navigationDelegate = context.coordinator
        webView.load(request)
        webView.isHidden = true
        //the view is hidden because it is not required for the app, it is only for retrieving the words
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        //required method part of UIViewRepresentable, but not implemented because it is not necessary for our use of the web view
    }
    
    /*
     
     getWords Function:
     
     This function is the core of grabbing the words from the website. This is done by executing a JavaScript command on the website to capture the most important HTML segments. Then, the individual words are parsed from the HTML using SwiftSoup, allowing us to have a final array of all of the daily Connections words.
     
     */
        
    func getWords(webView: WKWebView, completion: @escaping (_ success: Bool, _ data: [String]) -> Void) {
        //this function uses a completion handler to handle what happens after the task is completed
        var words: [String] = []
        let script = """
        var htmlString = ""
        for(let i = 0; i < 16; i++) {
            htmlString += new XMLSerializer().serializeToString(document.getElementById("item-" + i));
        }
        htmlString;
        """
        //executes this JavaScript command that gets the elements within the html that we need
        webView.evaluateJavaScript(script) { (result, error) in
            if let htmlString = result as? String {
                do {
                    //using SwiftSoup to parse html and retrieve just the words
                    let doc: Document = try SwiftSoup.parse(htmlString)
                    let elements: Elements = try doc.select("div.item")
                    for i in elements {
                        words.append(try i.text())
                    }
                    completion(true, words)
                }
                catch {
                    completion(false, words)
                }
            } else if let error = error {
                completion(false, words)
            }
        }
    }
}

/*
 
 ContentView Structure:
 
 Within this structure is all of the viewable assets when someone uses the app. First, the WordRetrieverView structure is called to retrieve the words from the NYT website, which is all hidden under a loading screen. Once this finishes, the user is directed to a simple starting page with a button to start the puzzle. After clicking the "Play Today's Puzzle" button, the grid is shown with all the words, with color-coded rows to highlight each group that that user makes. The drag and drop grid allows users to consider words that are associated, before being able to lock that row, which moves to ensure that it doesn't block the rest of the user's thinking in other categories. When stuck, there is a shuffle button which randomly orders the words in unlocked rows. This use of color-coded rows allows players to not only have a visual representation of the four words that they are trying to connect at the moment, but also gives a glimpse at the whole puzzle, allowing for the puzzle to be solved before a single chance is actually used in the realy game.
 
 */

struct ContentView: View {
    @ObservedObject var wordsObject: WebData = WebData()
    @State private var draggingItem: String?
    @State private var colors: [Color] = [Color.blue, Color.red, Color.green, Color.orange]
    @State private var locked: [Bool] = [false, false, false, false]
    @State private var game: Bool = false
    @State var size: CGSize = .zero
    
    /*
     
     lock Function:
     
     This function handles all of the logic when a row is locked by the user, including changing the appearance of the row, moving the row to the top, and making tiles in the locked row unable to be moved.
     
     */
    
    func lock(start: Int) {
        if !locked[start] {
            let row = locked.firstIndex(of: false)
            colors.swapAt(row!, start)
            locked[row!] = true
            for i in 0..<4 {
                withAnimation(.snappy) {
                    wordsObject.words.swapAt(row! * 4 + i, start * 4 + i)
                }
            }
        }
        else {
            let row = locked.lastIndex(of: true)
            colors.swapAt(row!, start)
            locked[row!] = false
            for i in 0..<4 {
                withAnimation(.snappy) {
                    wordsObject.words.swapAt(row! * 4 + i, start * 4 + i)
                }
            }
        }
    }
    
    var body: some View {
        if !self.wordsObject.isFinished {
            //this is the code for the loading screen, which allows for all of the words to be retrieved before the user attempts the puzzle
            WordRetrieverView(wordsObject: wordsObject).frame(width: 0, height: 0)
            //calls the WordRetrieverView structure
            VStack {
                Text("Getting Today's Connections").padding(20)
                ProgressView().scaleEffect(1.5)
            }
        }
        else {
            if !game {
                //this is the code for the simple starting screen, which helps organize the app and maintain a professional look
                VStack(spacing: 200) {
                    Text("Connections: See It")
                        .font(.system(size: 50, weight: .bold))
                    Button("Play Today's Puzzle", action:{
                        if self.wordsObject.isFinished {
                            self.game = true
                        }
                    })
                    .foregroundStyle(Color.gray)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 2).frame(width: 200, height: 40))
                }
            }
            if game {
                VStack {
                    Text("drag and drop words to make connections").padding(20).foregroundStyle(Color.gray)
                    /*
                     The Grid:
                     
                     This grid is the main part of the app, which shows every daily NYT Connections word on a simple interface. The color-coded rows allow for connections to be visualized, and the drag and drop feature makes it easy to try new combinations.
                     
                     The grid itself is a LazyVGrid with rounded rectangles that have the property of being draggable. Once they are dragged to a valid location, the tiles are swapped, with the words changed but the rows remaining the same colors.
                     
                     */
                    
                    let columns = Array(repeating: GridItem(spacing: 10), count: 4)
                    LazyVGrid(columns: columns, spacing: 10, content: {
                        ForEach(wordsObject.words, id: \.self) { word in
                            let row = wordsObject.words.firstIndex(of: word)! / 4
                            let fill = locked[row] ? colors[row] : Color.white
                            let font = locked[row] ? Color.white : Color.black
                            if(!locked[row]) {
                                GeometryReader { geometry in
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(fill)
                                        .stroke(colors[row], lineWidth: 2)
                                        .overlay(
                                            Text(word)
                                                .foregroundColor(font)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                        )
                                        .onAppear {
                                            size = geometry.size
                                        }
                                        .draggable(word) {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(.ultraThinMaterial)
                                                .overlay(
                                                    Text(word)
                                                        .foregroundColor(.black)
                                                        .lineLimit(1)
                                                        .minimumScaleFactor(0.5)
                                                )
                                                .frame(width: size.width, height: size.height)
                                                .onAppear {
                                                    draggingItem = word
                                                }
                                        }
                                        .dropDestination(for: String.self) { items, location in
                                            if let draggingItem, draggingItem != word {
                                                if let sourceIndex = wordsObject.words.firstIndex(of: draggingItem),
                                                   let finalIndex = wordsObject.words.firstIndex(of: word) {
                                                    withAnimation(.snappy) {
                                                        wordsObject.words.swapAt(sourceIndex, finalIndex)
                                                    }
                                                }
                                            }
                                            draggingItem = nil
                                            return true
                                        }
                                }.frame(height: 100)
                            }
                            else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(fill)
                                    .stroke(colors[row], lineWidth: 2)
                                    .frame(height: 100)
                                    .overlay(
                                        Text(word)
                                            .foregroundColor(font)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                    )
                            }
                        }
                    })
                    .padding(10)
                    
                    /*
                     
                     The Locking Feature:
                     
                     A row of four color-coded locks are underneath the grid which allow for connections to be secured when a user believes that they have correctly solved a portion of the puzzle or have checked words with the official game.
                     
                     */
                    HStack {
                        Button {
                            lock(start: 0)
                        } label: {
                            let design = locked[0] ? ".open" : ""
                            Image(systemName: "lock" + design + ".fill")
                                .background(RoundedRectangle(cornerRadius: 10).fill(colors[0]).frame(width: 40, height: 40))
                                .foregroundStyle(Color.white)
                        }
                        .padding(20)
                        Button {
                            lock(start: 1)
                        } label: {
                            let design = locked[1] ? ".open" : ""
                            Image(systemName: "lock" + design + ".fill")
                                .background(RoundedRectangle(cornerRadius: 10).fill(colors[1]).frame(width: 40, height: 40))
                                .foregroundStyle(Color.white)
                        }
                        .padding(20)
                        Button {
                            lock(start: 2)
                        } label: {
                            let design = locked[2] ? ".open" : ""
                            Image(systemName: "lock" + design + ".fill")
                                .background(RoundedRectangle(cornerRadius: 10).fill(colors[2]).frame(width: 40, height: 40))
                                .foregroundStyle(Color.white)
                        }
                        .padding(20)
                        Button {
                            lock(start: 3)
                        } label: {
                            let design = locked[3] ? ".open" : ""
                            Image(systemName: "lock" + design + ".fill")
                                .background(RoundedRectangle(cornerRadius: 10).fill(colors[3]).frame(width: 40, height: 40))
                                .foregroundStyle(Color.white)
                        }
                        .padding(20)
                    }.padding(20)
                    
                    /*
                     
                     The Shuffling Feature:
                     
                     Tiles that are not locked can be shuffled by clicking the button at the bottom of the screen, allowing for users to have another view of the puzzle without messing up previous work.
                     
                     */
                    
                    Button {
                        if let row = locked.firstIndex(of: false) {
                            let firstHalf = wordsObject.words[..<(row * 4)]
                            let secondHalf = wordsObject.words[(row * 4)...]
                            wordsObject.words = firstHalf + secondHalf.shuffled()
                        }
                    } label: {
                        Image(systemName: "shuffle")
                            .foregroundStyle(Color.gray)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
