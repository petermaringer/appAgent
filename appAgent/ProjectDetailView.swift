import SwiftUI

struct ProjectDetailView: View {
  @ObservedObject var project: ProjectEngine
  @EnvironmentObject var settings: AppSettings
  @State private var userPrompt: String = ""
  @State private var showingSettings: Bool = false
  @State private var isProcessing: Bool = false
  @State private var statusMessage: String = ""
  
  @AppStorage("githubToken") private var token: String = ""
  @AppStorage("githubOwner") private var owner: String = ""
  
  @State private var showingGitSheet: Bool = false
  
  @FocusState private var editorFocused: Bool
  
  struct FileSheetItem: Identifiable {
    let id = UUID()
    let url: URL
  }
  @State private var sheetItem: FileSheetItem? = nil
  
  @Environment(\.dismiss) private var dismiss
  //@Environment(\.safeAreaInsets) private var safeAreaInsets
  
  let kiService = KIService()
  
  var body: some View {
    /*let safeMaxWidth = calculateSafeMaxWidth(for: safeAreaInsets)
    userPrompt =  "\(safeMaxWidth)"
    //userPrompt =  "\(String(describing: safeMaxWidth))"*/
    ScrollView {
    //VStack(spacing: 10) {}
    VStack(alignment: .center, spacing: 12) {
      
      //userPrompt =  "\(containerRelativeFrame(.horizontal))"
      
      //Prompt-History
      if !project.promptHistory.isEmpty {
        ScrollView(.horizontal, showsIndicators: true) {
          HStack(spacing: 8) {
            ForEach(project.promptHistory, id: \.self) { prompt in
              Button {
                userPrompt = prompt
              } label: {
                Text(prompt)
                  .padding(6)
                  .background(Color.gray.opacity(0.1))
                  .cornerRadius(6)
              }
            }
          }
          .padding(.horizontal)
        }
      }
      
      //TextEditor
      TextEditor(text: $userPrompt)
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 18)
            .stroke(Color.gray.opacity(0.1), lineWidth: 3)
        )
        .frame(height: 110) //150
        //.frame(minHeight: 150, maxHeight: 250)
        .padding(.horizontal)
        .focused($editorFocused)
        
      //Buttonleiste
      HStack {
        Button {
          showingSettings.toggle()
        } label: {
          Image(systemName: "gearshape")
        }
        .padding(.leading)
        
        Spacer()
        
        Button {
          Task { await generateProject() }
        } label: {
          if isProcessing {
            ProgressView()
          } else {
            Text("KI-Code generieren").bold()
          }
        }
        .padding(.trailing)
        
        Button {
          gitPush()
          /*Task {
            let settingsURL = project.projectFolder.appendingPathComponent(".project.json")
            if FileManager.default.fileExists(atPath: settingsURL.path) {
              let gitService = GitHubService(token: token, repoOwner: owner, repoName: project.projectName)
              await gitService.pushProject(at: project.projectFolder) { status in
                statusMessage = status
              }
            } else {
              showingGitSheet = true
            }
          }*/
          /*Task {
            let gitService = GitHubService(token: token, repoOwner: owner, repoName: project.projectName)
            await gitService.pushProject(at: project.projectFolder) { status in
              statusMessage = status
            }
          }*/
        } label: {
          Text("GitHub Push").bold()
        }
        .padding(.trailing)
      }
      //.frame(maxWidth: .infinity)
      .padding(.horizontal)
      .background(Color.pink.opacity(0.05))
      
      //StatusMessage
      if !statusMessage.isEmpty {
        Text(statusMessage)
          .foregroundColor(settings.tintColor)
          //.foregroundColor(.blue)
          .padding(.horizontal)
          .background(Color.green.opacity(0.05))
      }
      
      //GitSectionView
      GitSectionView(project: project)
        .padding()
        /*.padding(.top)
        .padding(.horizontal)*/
        .background(Color.blue.opacity(0.03))
        
  //ZStack
  ZStack(alignment: .top) {
    //BackgroundLayer
    Color.yellow
    
    //GradientOverlayView
    //GradientOverlayView(gradientHeight: 16) {
    
    //FileListView
    FileListView(projectFolder: project.projectFolder)
      .frame(minHeight: 250, maxHeight: 400)
      .layoutPriority(1)
      .background(Color.clear)
      .padding(.horizontal)
      //.padding(.top, 16) //Damit Gradient nichts überdeckt
      
      /*.overlay(
        LinearGradient(
          gradient: Gradient(colors: [Color.red, Color(UIColor.systemBackground).opacity(0)]),
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: 16)
        .allowsHitTesting(false),
        alignment: .top
      )*/
      
      .onReceive(NotificationCenter.default.publisher(for: .openFileInEditor)) { notification in
        if let url = notification.object as? URL {
          sheetItem = FileSheetItem(url: url)
        }
      }
    //}
    
    //LinearGradient
    LinearGradient(
      gradient: Gradient(colors: [Color.red, Color.clear]),
      //Color.background //Mit Light-Dark Mode
      //Color(UIColor.systemBackground)
      startPoint: .top,
      endPoint: .bottom
    )
    .frame(height: 16) //50
    .allowsHitTesting(false)
  }
  
}
    .frame(maxWidth: .infinity)
    .background(
      ZStack {
        Color.yellow.opacity(0.08)
        ProjectDetailInteractivePopGestureEnabler()
        Group {
          if editorFocused {
            Color.clear
              .contentShape(Rectangle())
              .onTapGesture { editorFocused = false } //Keyboard weg
          }
        }
      }
    )
    .navigationTitle(project.projectName)
    .tint(settings.tintColor)
    
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "chevron.left")
            /*.foregroundColor(.blue)
            .padding(12)
            .contentShape(Rectangle())
            .opacity(isPressed ? 0.5 : 1)*/
        }
        .toolbarButton(.standard, tintColor: settings.tintColor)
        //.toolbarButton(.standard)
        //.buttonStyle(StandardToolbarButtonStyle())
        //.buttonStyle(.plain)
      }
    }
    /*.background(
      ProjectDetailInteractivePopGestureEnabler()
    )*/
    
    //.tint(.blue)
    //.toolbarColorScheme(.automatic, for: .navigationBar)
    /*.background(Color.yellow.opacity(0.05))
    .navigationTitle(project.projectName)
    .background(
      Group {
        if editorFocused {
          Color.clear
            .contentShape(Rectangle())
            .onTapGesture { editorFocused = false } //Keyboard weg
        }
      }
    )*/
    
    .sheet(isPresented: $showingSettings) {
      SettingsView()
        .environmentObject(settings)
    }
    .sheet(item: $sheetItem) { item in
      FileEditorView(fileURL: item.url)
        .environmentObject(settings)
    }
    .sheet(isPresented: $showingGitSheet) {
      GitSettingsSheet(project: project) { saved in
        if saved { gitPush() }
      }
      .environmentObject(settings)
    }
    .onAppear {
      userPrompt = "\(containerRelativeFrame(.horizontal))"
    }
    
    }
    
  }
  
  func generateProject() async {
    guard !userPrompt.isEmpty else {
      statusMessage = "Bitte Prompt eingeben."
      return
    }
    isProcessing = true
    statusMessage = ""
    do {
      try await project.generateOrUpdateProject(userPrompt: userPrompt, kiService: kiService)
      statusMessage = "✅ Projekt aktualisiert."
    } catch {
      statusMessage = "❌ Fehler: \(error.localizedDescription)"
    }
    isProcessing = false
  }
  
func gitPush() {
  let settingsURL = project.projectFolder.appendingPathComponent(".project.json")
  
  if FileManager.default.fileExists(atPath: settingsURL.path) {
    if let data = try? Data(contentsOf: settingsURL),
       let settings = try? JSONDecoder().decode(ProjectSettings.self, from: data) {
      Task {
        /*let gitService = GitHubService(
          token: token,
          repoOwner: owner,
          repoName: project.projectName,
          isPublic: settings.isPublic,
          branch: settings.branch
        )*/
        let gitService = GitHubService(token: token, repoOwner: owner, repoName: project.projectName)
        await gitService.pushProject(at: project.projectFolder) { status in
          statusMessage = status
        }
      }
    } else {
      //Datei beschädigt
      showingGitSheet = true
    }
  } else {
    //Settings existieren noch nicht
    showingGitSheet = true
  }
}
  
}

struct ProjectDetailInteractivePopGestureEnabler: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> UIViewController {
    let vc = UIViewController()
    DispatchQueue.main.async {
      if let nav = vc.navigationController {
        nav.interactivePopGestureRecognizer?.delegate = nil
        nav.interactivePopGestureRecognizer?.isEnabled = true
      }
    }
    return vc
  }
  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
