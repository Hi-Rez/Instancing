//
//  ContentView.swift
//  Instancing
//
//  Created by Reza Ali on 1/21/21.
//  Copyright © 2020 Reza Ali. All rights reserved.
//

import SwiftUI

import Forge
import Satin

struct ContentView: SwiftUI.View {
    @EnvironmentObject var renderer: Renderer

    var body: some SwiftUI.View {
        ZStack {
            ForgeView(renderer: renderer)
                .frame(minWidth: 512, minHeight: 512)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    ImageButton(
                        image: "Share_Small",
                        imageSize: 24,
                        imagePadding: 10,
                        color: Color("Button"),
                        action: {
                            self.renderer.exportImage()
                        }
                    )
                    .background(VisualEffectView())
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: Color.black.opacity(0.175), radius: 4, x: 0.0, y: 4)
                }
            }
            .padding(16)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some SwiftUI.View {
        ContentView().environmentObject(Renderer())
    }
}
