var g = require('./global')
  , xml2json = require('xml2json')
  ;

var proxyIOUs = {}

module.exports = {
  connect: function(casURL, casService, pgtUrl) {
    return {
      pgtCallback: function(pgtId, pgtIou) {
        proxyIOUs[pgtIou] = pgtId;
      },
      validateService: function(ticket, callback) {
        if ( !ticket ) return callback({code: 403, message: "No CAS ticket"});
        
        var validateServiceURL = g.format("%s/serviceValidate?ticket=%s&service=%s&pgtUrl=%s", casURL, ticket, casService, pgtUrl);
        g.getURL(validateServiceURL, { followRedirects: false, headers: { 'Accept': 'application/xml' } }, function(err, resultString) {
          if ( err ) return callback({code: 403, message: err});

          // <cas:serviceResponse xmlns:cas='http://www.yale.edu/tp/cas'>
          //     <cas:authenticationSuccess>
          //         <cas:user>endjs</cas:user>
          //         <cas:proxyGrantingTicket>PGTIOU-85-8PFx8qipjkWYDbuBbNJ1roVu4yeb9WJIRdngg7fzl523Eti2td</cas:proxyGrantingTicket>
          //     </cas:authenticationSuccess>
          // </cas:serviceResponse>      
          
          var result = xml2json.toJson(resultString, {object:true})['cas:serviceResponse'];
          var success, failure;
          // g.winston.info(g.inspect(result, false, null));
          if ( failure = result['cas:authenticationFailure'] )
            return callback({code: 403, message: failure.code });
          success = result['cas:authenticationSuccess'];

          var username = success['cas:user'];
          var iou = success['cas:proxyGrantingTicket'];
          if ( !iou ) return callback(g.format("Expecting cas:proxyGrantingTicket in %s", resultString));
          
          callback(null, username, proxyIOUs[iou]);
        });
      },
      proxy: function(targetService, pgtId, callback) {
        if ( !pgtId ) return callback("Missing pgtId");
        
        var proxyURL = g.format("%s/proxy?targetService=%s&pgt=%s", casURL, targetService, pgtId);
        g.getURL(proxyURL, { followRedirects: false, headers: { 'Accept': 'application/xml' } }, function(err, resultString) {
          if ( err ) return callback({code: 403, message: err});

          // <cas:serviceResponse>
          //     <cas:proxySuccess>
          //         <cas:proxyTicket>PT-957-ZuucXqTZ1YcJw81T3dxf</cas:proxyTicket>
          //     </cas:proxySuccess>
          // </cas:serviceResponse>            
          
          var result = xml2json.toJson(resultString, {object:true})['cas:serviceResponse'];
          var success, failure;
          // g.winston.info(g.inspect(result, false, null));

          if ( failure = result['cas:proxyFailure'] )
            return callback({code: 403, message: failure.code });
          success = result['cas:proxySuccess'];
          
          var proxyTicket = success['cas:proxyTicket'];
          callback(null, proxyTicket)
        });
      }
    }
  }
}
