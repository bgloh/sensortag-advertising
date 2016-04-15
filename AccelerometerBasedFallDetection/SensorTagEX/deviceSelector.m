/*
 *  deviceSelector.m
 *
 * Created by Ole Andreas Torvmark on 10/2/12.
 * Copyright (c) 2012 Texas Instruments Incorporated - http://www.ti.com/
 * ALL RIGHTS RESERVED
 * ***********************************
 * REVISION HISTORY
 * 12/31/2014: ONLY SELECTED SERVICES ARE CONNECTED.
 */

#import "deviceSelector.h"

@interface deviceSelector ()

@end

@implementation deviceSelector
@synthesize m,nDevices,sensorTags,i, accX, accY, accZ, rssi;
@synthesize serviceArray ; //added code, array to store services to connect



- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        self.m = [[CBCentralManager alloc]initWithDelegate:self queue:nil];
        self.nDevices = [[NSMutableArray alloc]init];
        self.sensorTags = [[NSMutableArray alloc]init];
        self.title = @"SensorTag advertisement Testing";
    }
    // TIMER
    NSTimer *rssiTimer;
    [rssiTimer invalidate];
    rssiTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(myTimer) userInfo:nil repeats:YES];
    return self;
}

// Scheduled Timer
-(void) myTimer
{
    //self.m = [[CBCentralManager alloc]initWithDelegate:self queue:nil];

   // NSLog(@"timer test");
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) viewWillAppear:(BOOL)animated {
    self.m.delegate = self;
    self.serviceArray = [self makeSensorTagConfiguration]; // added code for service selection(12/31)

}





#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return sensorTags.count;
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{

    UITableViewCell *cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:[NSString stringWithFormat:@"%d_Cell",indexPath.row]];
    CBPeripheral *p = [self.sensorTags objectAtIndex:indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@",p.name];
    
    // If periperal is SensorTag2.0, display manufacture-specific advertisement data in the detail text
    if([p.name isEqualToString:@"SensorTag 2.0"]) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"accZ:%1.1fG RSSI:%@dB",self.accZ,self.rssi];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

-(NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
       if (self.sensorTags.count > 1 )return [NSString stringWithFormat:@"%d BLE devices Found",self.sensorTags.count];
        else return [NSString stringWithFormat:@"%d BLE devices Found",self.sensorTags.count];
    }
    
    return @"";
}

-(float) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 150.0f;
}

#pragma mark - Table view delegate

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBPeripheral *p = [self.sensorTags objectAtIndex:indexPath.row];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    BLEDevice *d = [[BLEDevice alloc]init];
    
    d.p = p;
    d.manager = self.m;
    d.setupData = [self makeSensorTagConfiguration];
    
    SensorTagApplicationViewController *vC = [[SensorTagApplicationViewController alloc]initWithStyle:UITableViewStyleGrouped andSensorTag:d];
    [self.navigationController pushViewController:vC animated:YES];
    
}




#pragma mark - CBCentralManager delegate

-(void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    if (central.state != CBCentralManagerStatePoweredOn) {
        UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"BLE not supported !" message:[NSString stringWithFormat:@"CoreBluetooth return state: %d",central.state] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
    }
    else {
        // scan peripheral with callback notifications with every advertising packet from BLE device
        NSDictionary *options =[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],CBCentralManagerScanOptionAllowDuplicatesKey, nil];
        [central scanForPeripheralsWithServices:nil options:options];
        
    }
}




-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {

    BOOL replace = NO;
    unsigned char scratchVal[11];  // manufcature specific advertisement data
    NSLog(@"Found a BLE Device : %@",peripheral);
    
    /* iOS 6.0 bug workaround : connect to device before displaying UUID !
       The reason for this is that the CFUUID .UUID property of CBPeripheral
       here is null the first time an unkown (never connected before in any app)
       peripheral is connected. So therefore we connect to all peripherals we find.
    */
    
    //Before you begin interacting with the peripheral, you should set the peripheral’s delegate to ensure that it receives the appropriate callbacks
    peripheral.delegate = self;
    // [central connectPeripheral:peripheral options:nil]; // UNCOMMENT TO CONNECT
    
    // Match if we have this device from before. If we do, then don't add it to sensorTags object array
    for (int ii=0; ii < self.sensorTags.count; ii++) {
        CBPeripheral *p = [self.sensorTags objectAtIndex:ii];
        if ([p isEqual:peripheral]) {
            [self.sensorTags replaceObjectAtIndex:ii withObject:peripheral];
            replace = YES;
        }
    }
    if (!replace) {
        [self.sensorTags addObject:peripheral];
        [self.tableView reloadData];
    }
    
    // Save Manufacture-specific data from advertisement packet
    if([peripheral.name isEqualToString:@"SensorTag 2.0"]) {
        NSData *manufactureData = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
        [manufactureData getBytes:&scratchVal length:11];
        int16_t rawAccZ = (scratchVal[9] & 0xff) | ((scratchVal[10] << 8) & 0xff00);
        uint8_t accRange = 4; // 4G range
        self.accZ = (((float)rawAccZ * 1.0) / ( 32767 / accRange ));
        self.rssi = RSSI;                   // RSSI value
         NSLog(@"value: %1.1f",self.accZ);
        [self.tableView reloadData];
        NSLog(@"RSSI Requested: %@", RSSI); // RSSI value
    }
}

-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    BOOL found = NO;
    BOOL replace = NO;
    [peripheral discoverServices:nil];
//  CBUUID *sUUIDAcc = [CBUUID UUIDWithString:[self.serviceArray valueForKey:@"Accelerometer service UUID"]];
//  CBUUID *sUUIDGyro = [CBUUID UUIDWithString:[self.serviceArray valueForKey:@"Gyroscope service UUID"]];
    
    
 
    peripheral.delegate = self; //Before you begin interacting with the peripheral, you should set the peripheral’s delegate to ensure that it receives the appropriate callbacks

//    [peripheral discoverServices:nil];
//   [peripheral discoverServices:@[sUUIDAcc,sUUIDGyro]];
    
    // READ RSSI request
   /* peripheral.delegate = self;
    [peripheral readRSSI];
    NSLog(@"RSSI Requested");*/
    
   
}


#pragma  mark - CBPeripheral delegate

-(void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    BOOL replace = NO;
    BOOL found = NO;
    NSLog(@"Services scanned !");
    [self.m cancelPeripheralConnection:peripheral];
    
    // DISCOVER SENSORTAG ONLY
    for (CBService *s in peripheral.services) {
        NSLog(@"Service found : %@",s.UUID);
      //  if ([s.UUID isEqual:[CBUUID UUIDWithString:@"F000AA00-0451-4000-B000-000000000000"]])  {
        if ([s.UUID isEqual:[CBUUID UUIDWithString:[self.serviceArray valueForKey:@"Accelerometer service UUID"]]])
        {
            [peripheral discoverCharacteristics:nil forService:s];
            NSLog(@"This is a SensorTag !");
            found = YES;
                    }
    }
    
    // DISCOVER ALL BLE DEVICES
    found = YES;
    if (found) {
        // Match if we have this device from before
        for (int ii=0; ii < self.sensorTags.count; ii++) {
            CBPeripheral *p = [self.sensorTags objectAtIndex:ii];
            if ([p isEqual:peripheral]) {
                    [self.sensorTags replaceObjectAtIndex:ii withObject:peripheral];
                    replace = YES;
                }
            }
        if (!replace) {
            [self.sensorTags addObject:peripheral];
            [self.tableView reloadData];
        }
    }
    
}

-(void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
     NSLog(@"didDiscoverCharacteristicsForService %@, error = %@",service,error);
     [self startAccelerometer:peripheral];
    [self setNotificationForUpdate:peripheral];

    
}

-(void) peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"didUpdateNotificationStateForCharacteristic %@ error = %@",characteristic,error);
    
   
}

-(void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"didWriteValueForCharacteristic %@ error = %@",characteristic,error);
    
}

-(void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
 //    NSLog(@"didUpdateValueForCharacteristic %@ error = %@",characteristic.value,error);
    [peripheral readRSSI];
    peripheral.delegate = self;
}



-(void) peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error
{
    
    NSNumber *rssi = peripheral.RSSI;
  //  NSLog(@"Updated RSSI Ha Ha Ha");
  //  NSLog(@"RSSI:%@", rssi);
}

-(void) setNotificationForUpdate: (CBPeripheral *)peripheral
{
    
    //SENSORTAG
    CBUUID *sUUIDAcc = [CBUUID UUIDWithString:[self.serviceArray valueForKey:@"Accelerometer service UUID"]];
     CBUUID *cUUIDAccConfig = [CBUUID UUIDWithString:[self.serviceArray valueForKey:@"Accelerometer config UUID"]];
     CBUUID  *cUUIDAccData = [CBUUID UUIDWithString:[self.serviceArray valueForKey:@"Accelerometer data UUID"]];
   
     [BLEUtility setNotificationForCharacteristic:peripheral sCBUUID:sUUIDAcc  cCBUUID:cUUIDAccData enable:YES];
}

#pragma mark - SensorTag configuration

-(NSMutableDictionary *) makeSensorTagConfiguration {
    NSMutableDictionary *d = [[NSMutableDictionary alloc] init];
    // First we set ambient temperature
    [d setValue:@"0" forKey:@"Ambient temperature active"];
    // Then we set IR temperature
    [d setValue:@"0" forKey:@"IR temperature active"];
    // Append the UUID to make it easy for app
    [d setValue:@"F000AA00-0451-4000-B000-000000000000"  forKey:@"IR temperature service UUID"];
    [d setValue:@"F000AA01-0451-4000-B000-000000000000" forKey:@"IR temperature data UUID"];
    [d setValue:@"F000AA02-0451-4000-B000-000000000000"  forKey:@"IR temperature config UUID"];
    // Then we setup the accelerometer
    [d setValue:@"1" forKey:@"Accelerometer active"];  //milisecond
    [d setValue:@"100" forKey:@"Accelerometer period"];
    [d setValue:@"F000AA10-0451-4000-B000-000000000000"  forKey:@"Accelerometer service UUID"];
    [d setValue:@"F000AA11-0451-4000-B000-000000000000"  forKey:@"Accelerometer data UUID"];
    [d setValue:@"F000AA12-0451-4000-B000-000000000000"  forKey:@"Accelerometer config UUID"];
    [d setValue:@"F000AA13-0451-4000-B000-000000000000"  forKey:@"Accelerometer period UUID"];
    
    //Then we setup the rH sensor
    [d setValue:@"0" forKey:@"Humidity active"];
    [d setValue:@"F000AA20-0451-4000-B000-000000000000"   forKey:@"Humidity service UUID"];
    [d setValue:@"F000AA21-0451-4000-B000-000000000000" forKey:@"Humidity data UUID"];
    [d setValue:@"F000AA22-0451-4000-B000-000000000000" forKey:@"Humidity config UUID"];
    
    //Then we setup the magnetometer
    [d setValue:@"0" forKey:@"Magnetometer active"];
    [d setValue:@"500" forKey:@"Magnetometer period"]; // milisecond
    [d setValue:@"F000AA30-0451-4000-B000-000000000000" forKey:@"Magnetometer service UUID"];
    [d setValue:@"F000AA31-0451-4000-B000-000000000000" forKey:@"Magnetometer data UUID"];
    [d setValue:@"F000AA32-0451-4000-B000-000000000000" forKey:@"Magnetometer config UUID"];
    [d setValue:@"F000AA33-0451-4000-B000-000000000000" forKey:@"Magnetometer period UUID"];
    
    //Then we setup the barometric sensor
    [d setValue:@"0" forKey:@"Barometer active"];
    [d setValue:@"F000AA40-0451-4000-B000-000000000000" forKey:@"Barometer service UUID"];
    [d setValue:@"F000AA41-0451-4000-B000-000000000000" forKey:@"Barometer data UUID"];
    [d setValue:@"F000AA42-0451-4000-B000-000000000000" forKey:@"Barometer config UUID"];
    [d setValue:@"F000AA43-0451-4000-B000-000000000000" forKey:@"Barometer calibration UUID"];
    
    //Then we setup the gyroscope
    [d setValue:@"1" forKey:@"Gyroscope active"];
    [d setValue:@"100" forKey:@"gyroscope period"]; // milisecond
    [d setValue:@"F000AA50-0451-4000-B000-000000000000" forKey:@"Gyroscope service UUID"];
    [d setValue:@"F000AA51-0451-4000-B000-000000000000" forKey:@"Gyroscope data UUID"];
    [d setValue:@"F000AA52-0451-4000-B000-000000000000" forKey:@"Gyroscope config UUID"];
    [d setValue:@"F000AA53-0451-4000-B000-000000000000" forKey:@"Gyroscope period UUID"];
    
    //Then we setup connection control services
    [d setValue:@"1" forKey:@"RequestConnection active"];
    [d setValue:@"F000CCC0-0451-4000-B000-000000000000" forKey:@"Connection service UUID"];
    [d setValue:@"F000CCC2-0451-4000-B000-000000000000" forKey:@"RequestConnection UUID"];
    
    



   // NSLog(@"%@",d);
    
    return d;
}

-(void) startAccelerometer: (CBPeripheral *)peripheral
{
    CBUUID *sUUIDAcc = [CBUUID UUIDWithString:[self.serviceArray valueForKey:@"Accelerometer service UUID"]];
    CBUUID *cUUIDAccConfig = [CBUUID UUIDWithString:[self.serviceArray valueForKey:@"Accelerometer config UUID"]];
       uint8_t data = 0x01;
          [BLEUtility writeCharacteristic:peripheral sCBUUID:sUUIDAcc cCBUUID:cUUIDAccConfig data:[NSData dataWithBytes:&data length:1]];
}

@end
