var express = require('express');
var router = express.Router();
var MongoClient = require('mongodb').MongoClient;
var fs = require('fs');
var url = "mongodb://localhost:27017/";
var args = process.argv.slice(2);  // Geting command line arguments in array.
var rootpathofhostadpd = args[0] // Mention the root path where supplicant and hostapd present

/* GET home page. */
router.get('/', function(req, res, next) {
    res.render('qrcodesubmitpage')
});


/* POST QR code and DPP authnetication type. On sucessfull POST request authentication, configuration, network introduction */
router.post('/processqrcode', function(req, res) {
    console.log(req.body.qrcodetext);
    console.log(req.body.dppsecurity);
    console.log(req.body.password);
    if (!req.body.qrcodetext || !req.body.dppsecurity) {
        return res.status(400).end();
    }

    const ourexec = require('child_process').exec;
    ourexec("scripts/qr_monitor.sh " + "\"" + req.body.qrcodetext + "\"" + " " + rootpathofhostadpd  + " " + req.body.dppsecurity + " " + req.body.password, (error, stdout, stderr) => {
        console.log(stdout);
        console.log(stderr);
        console.log(error);
    })
    res.send("Recieved QR code ");
});

/* POST request to store dpp credentials to the server */
router.post('/storeddppcredentials', function(req, res) {
    console.log(req.body.dppconnector)
    console.log(req.body.dppcsign)
    console.log(req.body.dppnetaccesskey)
    console.log(req.body.dppconfigkey)
    console.log(req.body.macaddress)

    if (!req.body.dppconnector || !req.body.dppcsign || !req.body.dppnetaccesskey || !req.body.dppconfigkey || !req.body.macaddress) {
        return res.status(400).end();
    }
    MongoClient.connect(url, function(err, db) {
        if (err) throw err;
        var dbo = db.db("dppdatabase");
        dbo.collection("dppcollection").insertOne(req.body, function(err, res) {
            if (err) throw err;
            console.log("1 document inserted");
            db.close();
        });
    });
    return res.status(200).send('Recieved Data').end();
});

/* Get all the DPP configurations stored in server */
router.get('/getallconfig', function(req, res) {

    MongoClient.connect(url, function(err, db) {
        if (err) throw err;
        var dbo = db.db("dppdatabase");
        dbo.collection("dppcollection").find({}).toArray(function(err, result) {
            if (err) throw err;
            console.log(result);
            db.close();
            var parsedresult = JSON.stringify(result);
            res.send(result);
        });
    });

});

/* GET a random DPP configuration */
router.get('/getrandomdppconfig', function(req, res) {
    MongoClient.connect(url, function(err, db) {
        if (err) throw err;
        var dbo = db.db("dppdatabase");
        dbo.collection("dppcollection").aggregate([{
            $sample: {
                size: 1
            }
        }]).toArray(function(err, result) {
            if (err) throw err;
            console.log(result);
            db.close();
            var parsedresult = JSON.stringify(result);
            res.send(result);
        });
    });

});

/* GET DPP configuration based on MAC Address */
router.get('/getconfig/:macaddress', function(req, res) {
    console.log(req.params.macaddress)
    MongoClient.connect(url, function(err, db) {
        if (err) throw err;
        var dbo = db.db("dppdatabase");
        var query = {
            macaddress: req.params.macaddress
        };
        dbo.collection("dppcollection").find(query).toArray(function(err, result) {
            if (err) throw err;
            console.log(result);
            db.close();
            var parsedresult = JSON.stringify(result);
            res.send(result);
        });
    });
});

module.exports = router;
