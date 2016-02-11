/*
 *  deviceSelector.h
 *
 * Created by Ole Andreas Torvmark on 10/2/12.
 * Copyright (c) 2012 Texas Instruments Incorporated - http://www.ti.com/
 * ALL RIGHTS RESERVED
 */

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "BLEDevice.h"
#import "SensorTagApplicationViewController.h"

@interface deviceSelector : UITableViewController <CBCentralManagerDelegate,CBPeripheralDelegate>

@property (strong,nonatomic) CBCentralManager *m;
@property                    int16_t           i;  // counting index
@property                    float           accX,accY,accZ; // advertisement acceleration data
@property (strong,nonatomic) NSMutableArray *nDevices;
@property (strong,nonatomic) NSMutableArray *sensorTags;
@property (strong,nonatomic) NSMutableArray *serviceArray;




-(NSMutableDictionary *) makeSensorTagConfiguration;

-(void) startAccelerometer: (CBPeripheral *)peripheral;

@end

