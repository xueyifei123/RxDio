library rxdio;

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdio/com/kukugtu/rxdio/utils/NetUtils.dart';
import 'package:rxdio/com/kukugtu/rxdio/utils/TextUtil.dart';
import 'NetCallBack.dart';

class RxDio<T> {
  String _baseurl;
  String _path;
  REQUEST_METHORD _requestMethord;
  CacheMode _cacheMode = CacheMode.NO_CACHE;
  Map<String, String> _params;

  RxDio() : super();

  void setBaseUrl(String url) {
    this._baseurl = url;
  }

  void setPath(String path) {
    if (TextUtil.isEmpty(path)) {
      throw new Exception("path can not be null!");
      return;
    }
    this._path = path;
  }

  void setMethord(REQUEST_METHORD requestMethord) {
    this._requestMethord = requestMethord;
  }

  void setParams(Map<String, String> params) {
    this._params = params;
  }

  void setCacheMode(CacheMode cacheMode) {
    this._cacheMode = cacheMode;
  }

  void call(NetCallback<T> netCallback) {
    StreamController<RequestData<T>> controller =
        new StreamController<RequestData<T>>();

    Observable(controller.stream).listen((requestData) {
      if (requestData.requestType == RequestType.NET) {
        netCallback.onNetFinish(requestData.data);
      } else if (requestData.requestType == RequestType.CACHE) {
        netCallback.onCacheFinish(requestData.data);
      } else {
        netCallback.onUnkownFinish(requestData.data);
      }
    });

    if (_cacheMode == CacheMode.NO_CACHE) {
      //只获取网络
      if (_requestMethord == REQUEST_METHORD.GET) {
        Future<Response<T>> future =
            NetUtils.getNet<T>(_baseurl + _path, _params);
        future.then((response) {
          controller.add(new RequestData(
              requestType: RequestType.NET, data: response.data));
        });
      } else if (_requestMethord == REQUEST_METHORD.GET) {
        Future<Response<T>> future =
            NetUtils.postNet<T>(_baseurl + _path, _params);
        future.then((response) {
          controller.add(new RequestData(
              requestType: RequestType.NET, data: response.data));
        });
      }
    } else if (_cacheMode == CacheMode.FIRST_CACHE_THEN_REQUEST) {
      //先获取缓存，在获取网络
      NetUtils.getCache(_baseurl + _path, _params).then((list) {
        if (list.length > 0) {
          controller.add(new RequestData(
              requestType: RequestType.CACHE,
              data: json.decoder.convert(list[0]["value"]) as T,
              statusCode: 200));
        } else {
          controller.add(new RequestData(
              requestType: RequestType.CACHE, data: null, statusCode: 400));
        }
      });

      if (_requestMethord == REQUEST_METHORD.GET) {
        NetUtils.getNet<T>(_baseurl + _path, _params).then((response) {
          controller.add(new RequestData(
              requestType: RequestType.NET, data: response.data));
          NetUtils.saveCache(
              NetUtils.getCacheKeyFromPath(_baseurl + _path, _params),
              json.encoder.convert(response.data));
        });
      } else if (_requestMethord == REQUEST_METHORD.GET) {
        NetUtils.postNet<T>(_baseurl + _path, _params).then((response) {
          controller.add(new RequestData(
              requestType: RequestType.NET, data: response.data));
          NetUtils.saveCache(
              NetUtils.getCacheKeyFromPath(_baseurl + _path, _params),
              json.encoder.convert(response.data));
        });
      }
    } else if (_cacheMode == CacheMode.REQUEST_FAILED_READ_CACHE) {
      if (_requestMethord == REQUEST_METHORD.GET) {
        NetUtils.getNet<T>(_baseurl + _path, _params).then((response) {
          if (response.statusCode == 200) {
            controller.add(new RequestData(
                requestType: RequestType.NET, data: response.data));
          } else {
            NetUtils.getCache(_baseurl + _path, _params).then((list) {
              if (list.length > 0) {
                controller.add(new RequestData(
                    requestType: RequestType.CACHE,
                    data: json.decoder.convert(list[0]["value"]) as T,
                    statusCode: 200));
              } else {
                controller.add(new RequestData(
                    requestType: RequestType.CACHE,
                    data: null,
                    statusCode: 400));
              }
            });
          }
        });
      } else if (_requestMethord == REQUEST_METHORD.GET) {
        NetUtils.postNet<T>(_baseurl + _path, _params).then((response) {
          if (response.statusCode == 200) {
            controller.add(new RequestData(
                requestType: RequestType.NET, data: response.data));
          } else {
            NetUtils.getCache(_baseurl + _path, _params).then((list) {
              if (list.length > 0) {
                controller.add(new RequestData(
                    requestType: RequestType.CACHE,
                    data: json.decoder.convert(list[0]["value"]) as T,
                    statusCode: 200));
              } else {
                controller.add(new RequestData(
                    requestType: RequestType.CACHE,
                    data: null,
                    statusCode: 400));
              }
            });
          }
        });
      }
    } else if (_cacheMode == CacheMode.DEFAULT) {}
  }
}

enum REQUEST_METHORD {
  GET,
  POST,
}