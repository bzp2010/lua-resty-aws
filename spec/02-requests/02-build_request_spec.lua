local cjson = require "cjson"

describe("operations protocol", function()


  local build_request
  local operation, operation_with_payload_field
  local config, config_with_payload
  local params, params_with_payload
  local snapshot
  local binary_data

  setup(function()
    snapshot = assert:snapshot()
    assert:set_parameter("TableFormatLevel", -1)
    build_request = require("resty.aws.request.build")
  end)


  teardown(function()
    build_request = nil
    package.loaded["resty.aws"] = nil
    package.loaded["resty.aws.request.build"] = nil
    snapshot:revert()
  end)


  before_each(function()
    binary_data = "abcd" --"\00\01\02\03"

    operation = {
      name = "AssumeRole",
      http = {
        method = "POST",
        requestUri = "/{Operation+}/{InstanceId}?nice",
      },
      input = {
        type = "structure",
        required = {
          "RoleArn",
          "RoleSessionName"
        },
        members = {
          -- uri location
          InstanceId = {
            type = "string",
            location = "uri",
            locationName = "InstanceId"
          },
          Operation = {
            type = "string",
            location = "uri",
            locationName = "Operation"
          },
          RawBody = {
            type = "blob",
          },
          -- querystring location
          UserId = {
            type = "string",
            location = "querystring",
            locationName = "UserId"
          },
          -- header location
          Token = {
            type = "string",
            location = "header",
            locationName = "X-Sooper-Secret"
          },
          -- members without location
          RoleArn = {
            type = "string",
          },
          RoleSessionName = {
            type = "string",
          },
          BinaryData = {
            type = "blob",
          },
          subStructure = {
            locationName = "someSubStructure",
            type = "structure",
            members = {
              hello = {
                type = "string",
              },
              world = {
                type = "string",
              },
            }
          },
          subList = {
            type = "list",
            member = {
              type = "integer",
              locationName = "listELement"
            }
          }
        }
      }
    }

    operation_with_payload_field = {
      name = "PutObject",
      http = {
        method = "PUT",
        requestUri = "/{Bucket}/{Key+}"
      },
      input = {
        type = "structure",
        required = {
          "Bucket",
          "Key"
        },
        members = {
          Bucket = {
            type = "string",
            location = "uri",
            locationName = "Bucket"
          },
          Key = {
            type = "string",
            location = "uri",
            locationName = "Key"
          },
          Body = {
            type = "blob",
          },
        },
        payload = "Body"
      },
    }

    config = {
      apiVersion = "2011-06-15",
      --endpointPrefix = "sts",
      signingName = "sts",
      globalEndpoint = "sts.amazonaws.com",
      --protocol = "query",
      serviceAbbreviation = "AWS STS",
      serviceFullName = "AWS Security Token Service",
      serviceId = "STS",
      signatureVersion = "v4",
      uid = "sts-2011-06-15",
      xmlNamespace = "https://sts.amazonaws.com/doc/2011-06-15/"
    }

    config_with_payload = {
      apiVersion = "2006-03-01",
      signingName = "s3",
      globalEndpoint = "s3.amazonaws.com",
      --protocol = "query",
      serviceAbbreviation = "AWS S3",
      serviceFullName = "AWS Object Storage",
      serviceId = "S3",
      signatureVersion = "v4",
      uid = "s3-2006-03-01",
      xmlNamespace = "https://s3.amazonaws.com/doc/2006-03-01/"
    }

    params = {
      RoleArn = "hello",
      RoleSessionName = "world",
      InstanceId = "42",
      Operation = "hello world",
      UserId = "Arthur Dent",
      Token = "towel",
      subStructure = {
        hello = "the default hello thinghy",
        world = "the default world thinghy"
      },
      subList = { 1, 2 ,3, },
      BinaryData = binary_data,
    }

    params_with_payload = {
      Bucket = "hello",
      Key = "world",
      Body = binary_data,
    }

  end)


  it("errors on a bad protocol", function()

    config.protocol = "shake hands"

    assert.has.error(function()
      build_request(operation, config, params)
    end, "Bad config, field protocol is invalid, got: 'shake hands'")
  end)


  it("query: params go into query table, target action+version added", function()

    config.protocol = "query"
    params.subList = nil
    params.subStructure = nil

    local request = build_request(operation, config, params)
    assert.same({
      headers = {
        ["Accept"] = 'application/json',
        ["X-Sooper-Secret"] = "towel",
        ["X-Amz-Target"] = "sts.AssumeRole",
        ["Host"] = "sts.amazonaws.com",
      },
      method = 'POST',
      path = '/hello%20world/42',
      host = 'sts.amazonaws.com',
      port = 443,
      query = {
        RoleArn = 'hello',
        RoleSessionName = 'world',
        UserId = "Arthur Dent",
        Action = "AssumeRole",
        Version = "2011-06-15",
        nice = '',
        BinaryData = binary_data,
      }
    }, request)
  end)


  it("rest-json: querystring, uri, header and body params", function()

    config.protocol = "rest-json"

    local request = build_request(operation, config, params)
    if request and request.body then
      -- cannot reliably compare non-canonicalized json, so decode to Lua table
      request.body = assert(cjson.decode(request.body))
    end

    assert.same({
      headers = {
        ["Accept"] = 'application/json',
        ["X-Sooper-Secret"] = "towel",
        ["Content-Length"] = 172,
        ["Content-Type"] = "application/x-amz-json-1.0",
        ["X-Amz-Target"] = "sts.AssumeRole",
        ["Host"] = "sts.amazonaws.com",
      },
      method = 'POST',
      path = '/hello%20world/42',
      host = 'sts.amazonaws.com',
      port = 443,
      body = {
        subStructure = {
          hello = "the default hello thinghy",
          world = "the default world thinghy",
        },
        subList = { 1,2,3 },
        RoleArn = "hello",
        RoleSessionName = "world",
        BinaryData = binary_data,
      },
      query = {
        UserId = "Arthur Dent",
        nice = '',
      },
    }, request)
  end)


  it("json: querystring, uri, header and body params", function()

    config.protocol = "json"

    local request = build_request(operation, config, params)
    if request and request.body then
      -- cannot reliably compare non-canonicalized json, so decode to Lua table
      request.body = assert(cjson.decode(request.body))
    end

    assert.same({
      headers = {
        ["Accept"] = 'application/json',
        ["X-Sooper-Secret"] = "towel",
        ["Content-Length"] = 172,
        ["Content-Type"] = "application/x-amz-json-1.0",
        ["X-Amz-Target"] = "sts.AssumeRole",
        ["Host"] = "sts.amazonaws.com",
      },
      method = 'POST',
      path = '/hello%20world/42',
      host = 'sts.amazonaws.com',
      port = 443,
      body = {
        subStructure = {
          hello = "the default hello thinghy",
          world = "the default world thinghy",
        },
        subList = { 1,2,3 },
        RoleArn = "hello",
        RoleSessionName = "world",
        BinaryData = binary_data,
      },
      query = {
        UserId = "Arthur Dent",
        nice = '',
      }
    }, request)
  end)

  it("json: querystring, uri, header and body params, with payload field", function()

    config_with_payload.protocol = "json"

    local request = build_request(operation_with_payload_field, config_with_payload, params_with_payload)

    assert.same({
      headers = {
        ["Accept"] = 'application/json',
        ["Content-Length"] = 4,
        ["X-Amz-Target"] = "s3.PutObject",
        ["Host"] = "s3.amazonaws.com",
      },
      method = 'PUT',
      path = '/hello/world',
      host = 's3.amazonaws.com',
      port = 443,
      body = binary_data,
      query = {},
    }, request)
  end)


  pending("ec2: querystring, uri, header and body params", function()

    config.protocol = "ec2"

    assert.has.error(function()
      build_request(operation, config, params)
    end, "protocol 'ec2' not implemented yet")
  end)


end)
