//
//  EmojiArtDocumentView.swift
//  Emoji Art
//
//  Created by CS193p Instructor on 5/8/23.
//  Copyright (c) 2023 Stanford University
//

import SwiftUI

struct EmojiArtDocumentView: View {
    typealias Emoji = EmojiArt.Emoji
    
    @ObservedObject var document: EmojiArtDocument
    @State private var isAlertShowing: Bool = false
    private let paletteEmojiSize: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 0) {
            documentBody
            PaletteChooser()
                .font(.system(size: paletteEmojiSize))
                .padding(.horizontal)
                .scrollIndicators(.hidden)
        }
    }
    
    private var documentBody: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                documentContents(in: geometry)
                    .scaleEffect(zoom * gestureZoom)
                    .offset(pan + gesturePan)
            }
            .gesture(panGesture.simultaneously(with: zoomGesture))
            .dropDestination(for: Sturldata.self) { sturldatas, location in
                return drop(sturldatas, at: location, in: geometry)
            }
            .onTapGesture { selectedEmojiIDs.removeAll() }
        }
        .alert("Do you want to delete all selected emojis?", isPresented: $isAlertShowing) {
            Button("Delete", role: .destructive) { deleteSelectedEmojis() }
        }
    }
    
    @ViewBuilder
    private func documentContents(in geometry: GeometryProxy) -> some View {
        AsyncImage(url: document.background)
            .position(Emoji.Position.zero.in(geometry))
        
        ForEach(document.emojis) { emoji in
            Text(emoji.string)
                .font(emoji.font)
                .shadow(color: selectedEmojiIDs.contains(emoji.id) ? .teal : .clear, radius: 5)
                .offset(offSetSelector(emojiWithId: emoji.id))
                .scaleEffect(selectedEmojiIDs.contains(emoji.id) ? emojiGestureZoom : 1)
                .gesture(emojiPanGesture(emojiWithId: emoji.id))
                .onTapGesture { emojiSelectToggle(emojiWithId: emoji.id) }
                .onLongPressGesture { if !selectedEmojiIDs.isEmpty { isAlertShowing = true }
                }
                .position(emoji.position.in(geometry))
        }
    }
    
    @State private var selectedEmojiIDs: Set<EmojiArt.Emoji.ID> = []
    @State private var zoom: CGFloat = 1
    @State private var pan: CGOffset = .zero
    
    @GestureState private var gestureZoom: CGFloat = 1
    @GestureState private var gesturePan: CGOffset = .zero
    @GestureState private var emojiGesturePan: CGOffset = .zero
    @GestureState private var emojiGestureZoom: CGFloat = 1
    @GestureState private var emojiIdGesturePanPair: [Emoji.ID : CGOffset] = [:]
    
    private var zoomGesture: some Gesture {
        if selectedEmojiIDs.isEmpty {
            return  MagnificationGesture()
                .updating($gestureZoom) { inMotionPinchScale, gestureZoom, _ in
                    gestureZoom = inMotionPinchScale
                }
                .onEnded { endingPinchScale in
                    zoom *= endingPinchScale
                }
        } else {
            return MagnificationGesture()
                .updating($emojiGestureZoom) { inMotionPinchScale, emojiGestureZoom, _ in
                    emojiGestureZoom = inMotionPinchScale
                }
                .onEnded { endingPinchScale in
                    selectedEmojiIDs.forEach { emojiId in
                        document.resize(emojiWithId: emojiId, by: endingPinchScale)
                    }
                }
        }
    }
    
    private var panGesture: some Gesture {
        DragGesture()
            .updating($gesturePan) { inMotionDragGestureValue, gesturePan, _ in
                gesturePan = inMotionDragGestureValue.translation
            }
            .onEnded { endingDragGestureValue in
                pan += endingDragGestureValue.translation
            }
    }
    
    private func emojiPanGesture(emojiWithId id: Emoji.ID) -> some Gesture {
        DragGesture()
            .updating($emojiIdGesturePanPair) { inMotionDragGestureValue, emojiIdGesturePanPair, _ in
                let gesturePan = inMotionDragGestureValue.translation
                emojiIdGesturePanPair = [id: gesturePan]
            }
            .updating($emojiGesturePan) { inMotionDragGestureValue, emojiGesturePan, _ in
                if selectedEmojiIDs.contains(id) {
                    emojiGesturePan = inMotionDragGestureValue.translation
                }
            }
            .onEnded { dragGestureValue in
                if selectedEmojiIDs.contains(id) {
                    selectedEmojiIDs.forEach { emojiId in
                        document.move(emojiWithId: emojiId, by: dragGestureValue.translation)
                    }
                } else {
                    document.move(emojiWithId: id, by: dragGestureValue.translation)
                }
            }
    }
    
    private func drop(_ sturldatas: [Sturldata], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        for sturldata in sturldatas {
            switch sturldata {
            case .url(let url):
                document.setBackground(url)
                return true
            case .string(let emoji):
                document.addEmoji(
                    emoji,
                    at: emojiPosition(at: location, in: geometry),
                    size: paletteEmojiSize / zoom
                )
                return true
            default:
                break
            }
        }
        return false
    }
    
    private func emojiPosition(at location: CGPoint, in geometry: GeometryProxy) -> Emoji.Position {
        let center = geometry.frame(in: .local).center
        return Emoji.Position(
            x: Int((location.x - center.x - pan.width) / zoom),
            y: Int(-(location.y - center.y - pan.height) / zoom)
        )
    }
    
    private func emojiSelectToggle(emojiWithId id: EmojiArt.Emoji.ID) {
        if selectedEmojiIDs.contains(id) {
            selectedEmojiIDs.remove(id)
        } else {
            selectedEmojiIDs.insert(id)
        }
    }
    
    private func deleteSelectedEmojis() {
        selectedEmojiIDs.forEach { id in
            document.removeEmoji(withEmojiId: id)
        }
        selectedEmojiIDs.removeAll()
    }
    
    private func offSetSelector(emojiWithId id: Emoji.ID) -> CGOffset {
        if  let offset = emojiIdGesturePanPair[id] {
            return offset
        } else if selectedEmojiIDs.contains(id) {
            return emojiGesturePan
        } else {
            return .zero
        }
    }
}

struct EmojiArtDocumentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
            .environmentObject(PaletteStore(named: "Preview"))
    }
}
