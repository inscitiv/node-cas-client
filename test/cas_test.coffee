assert = require('assert')
gently = new (require('gently'))
g = require('../lib/global')

casURL = "https://cas.example.com"
casService = "https://myself.example.com"
proxyService = "https://proxy-service.example.com"
pgtUrl = "https://myself.example.com/pgtCallback"
username = "the-user"
pgtIou = 'PGTIOU-for-the-ticket'
ticket = 'the-ticket'
pgtId = 'PGT-proxy-granting-ticket'
proxyTicket = 'PT-proxy-ticket'

authn = require('../lib/cas').connect(casURL, casService, pgtUrl)

describe "cas", ->
  describe "#validateService", ->
    describe 'without a ticket', ->
      it 'returns 403', (done)->
        authn.validateService null, (err)->
          assert.equal 403, err.code
          done()
  
    describe "with a ticket", ->
      mockResponse = (theErr, theResult)->
        gently.expect g, 'getURL', (url, options, cb)->
          assert.equal url, "https://cas.example.com/serviceValidate?ticket=#{ticket}&service=#{casService}&pgtUrl=#{pgtUrl}"
          cb(theErr, theResult)
    
      it 'INVALID response from CAS returns 403', (done)->
        message = """
<cas:serviceResponse xmlns:cas='http://www.yale.edu/tp/cas'>
    <cas:authenticationFailure code="INVALID_TICKET">
        Ticket ST-1856339-aA5Yuvrxzpv8Tau1cYQ7 not recognized
    </cas:authenticationFailure>
</cas:serviceResponse>
        """
        mockResponse(null, message)
        authn.validateService ticket, (err)->
          assert.equal 403, err.code
          assert.equal 'INVALID_TICKET', err.message
          done()
          
      it 'error response from CAS returns 403', (done)->
        mockResponse("error", null)
        authn.validateService ticket, (err)->
          assert.equal err.code, 403
          assert.equal err.message, "error"
          done()
      
      describe 'which is valid', ->
        beforeEach ->
          message = """
<cas:serviceResponse xmlns:cas='http://www.yale.edu/tp/cas'>
    <cas:authenticationSuccess>
        <cas:user>#{username}</cas:user>
        <cas:proxyGrantingTicket>#{pgtIou}</cas:proxyGrantingTicket>
    </cas:authenticationSuccess>
</cas:serviceResponse>
          """
          mockResponse(null, message)
        
        it 'returns the username and pgtId', (done)->
          authn.pgtCallback pgtId, pgtIou
          authn.validateService ticket, (err, _username, _pgtId)->
            assert !err
            assert.equal _username, username
            assert.equal _pgtId, pgtId
            done()
            
  describe "#proxy", ->
    describe 'without a pgtId', ->
      it 'returns an error', (done)->
        authn.proxy proxyService, null, (err)->
          assert err
          done()

    describe 'with pgtId', ->
      mockResponse = (theErr, theResult)->
        gently.expect g, 'getURL', (url, options, cb)->
          assert.equal url, "https://cas.example.com/proxy?targetService=#{proxyService}&pgt=#{pgtId}"
          cb(theErr, theResult)

      describe 'and CAS failure', ->
        it 'returns 403 and the error code', (done)->
          message = """
<cas:serviceResponse>
    <cas:proxyFailure code="INVALID_REQUEST">
    An error message
    </cas:proxyFailure>
</cas:serviceResponse>            
          """
          
          mockResponse null, message
          authn.proxy proxyService, pgtId, (err)->
            assert.deepEqual err, {code: 403, message: 'INVALID_REQUEST'}
            done()
        
      describe 'and CAS success', ->
        it 'obtains the proxy ticket', (done)->
          message = """
<cas:serviceResponse>
    <cas:proxySuccess>
        <cas:proxyTicket>#{proxyTicket}</cas:proxyTicket>
    </cas:proxySuccess>
</cas:serviceResponse>            
          """
          
          mockResponse null, message
          authn.proxy proxyService, pgtId, (err, _proxyTicket)->
            assert !err
            assert.equal _proxyTicket, proxyTicket
            done()
        
