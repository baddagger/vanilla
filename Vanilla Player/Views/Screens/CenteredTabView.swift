import SwiftUI

struct CenteredTabView: View {
    let tabs: [String]
    @Binding var selectedIndex: Int
    let onTabChange: ((Int) -> Void)?

    @Namespace private var animation
    @State private var tabSizes: [Int: CGSize] = [:]
    @State private var containerWidth: CGFloat = 0

    var normalFontSize: CGFloat = 16
    var selectedFontSize: CGFloat = 24
    var tabSpacing: CGFloat = 40
    var selectedTextColor: Color
    var unselectedTextColor: Color

    init(
        tabs: [String],
        selectedIndex: Binding<Int>,
        normalFontSize: CGFloat = 16,
        selectedFontSize: CGFloat = 24,
        tabSpacing: CGFloat = 40,
        selectedTextColor: Color = .primary,
        unselectedTextColor: Color = .secondary,
        onTabChange: ((Int) -> Void)? = nil
    ) {
        self.tabs = tabs
        _selectedIndex = selectedIndex
        self.normalFontSize = normalFontSize
        self.selectedFontSize = selectedFontSize
        self.tabSpacing = tabSpacing
        self.selectedTextColor = selectedTextColor
        self.unselectedTextColor = unselectedTextColor
        self.onTabChange = onTabChange
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: tabSpacing) {
                    ForEach(0 ..< tabs.count, id: \.self) { index in
                        Text(tabs[index])
                            .italic()
                            .font(
                                .system(
                                    size: selectedIndex == index
                                        ? selectedFontSize : normalFontSize,
                                    design: .serif
                                )
                            )
                            .foregroundColor(
                                selectedIndex == index
                                    ? selectedTextColor : unselectedTextColor
                            )
                            .id(index)
                            .onTapGesture {
                                withAnimation {
                                    selectedIndex = index
                                    onTabChange?(index)
                                    proxy.scrollTo(index, anchor: .center)
                                }
                            }
                    }
                }
                .padding(.horizontal, containerWidth / 2)
            }
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { containerWidth = geo.size.width }
                        .onChange(of: geo.size.width) { width in
                            containerWidth = width
                        }
                }
            )
            .onChange(of: selectedIndex) { newIndex in
                withAnimation {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onAppear {
                // Scroll to initial selection
                proxy.scrollTo(selectedIndex, anchor: .center)
            }
        }
    }
}

struct CenteredTabViewExample: View {
    @State private var selectedTab = 0
    let tabs = ["Now Playing", "Playlist"]

    var body: some View {
        VStack(spacing: 0) {
            CenteredTabView(
                tabs: tabs,
                selectedIndex: $selectedTab,
                normalFontSize: 16,
                selectedFontSize: 24,
                tabSpacing: 40,
                selectedTextColor: .primary,
                unselectedTextColor: .secondary,
                onTabChange: { index in
                    selectedTab = index
                }
            )
        }
    }
}

#Preview {
    CenteredTabViewExample()
}
