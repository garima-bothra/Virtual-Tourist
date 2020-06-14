//
//  GCD.swift
//  Virtual Tourist
//
//  Created by Garima Bothra on 15/05/20.
//  Copyright © 2020 Garima Bothra. All rights reserved.
//

import Foundation

func performUIUpdatesOnMain(_ updates: @escaping () -> Void) {
    DispatchQueue.main.async {
        updates()
    }
}
