# Kong Middleman 请求转发插件

## 简介

在反向代理之前将请求截获转发给第三方处理程序，一般用于鉴权，逻辑如下：

- 1 客户端发送请求
- 2 Kong 接收请求，传递给 Middleman 插件
- 3 Middleman 插件传递请求给处理服务
- 4 处理服务根据原始请求的头部、参数、内容等信息结合业务逻辑判断该请求是否合法
  - 4.1 合法返回小于 299 的状态码，Middleman 插件允许请求通过
  - 4.2 不合法返回大于 299 的状态码和内容，Middleman 插件直接返回给客户端

## 版本要求

Kong >= 0.14.1

## 修改说明

插件fork自konga的作者，并做了如下修改：

- 请求转发从使用`ngx.socket`修改为`resty.http`，主要是原版的处理有问题，对处理服务的返回有要求，比如必须含有`content-length`，不然无法解析
- 错误处理方式修改为处理服务有问题则直接返回错误信息，原版会直接通过，存在安全隐患。注：`ssl handshake`错误和`keepalive`错误不做特殊处理
- 修改插件配置中的`respone`选项为`content-type`类型选择
- 修改默认读取 Body 为配置，处理策略为：如果是 Json，直接转发，如果不是，Json Encode之后转发
- 修改json处理模块为`cjson`

## 配置说明

| 配置项 | 默认值 | 说明 |
| - | - | - |
| url |  | 处理服务url，不能使用upstream名 |
| response | application/json | 处理服务返回大于299的状态码时返回的信息格式 |
| timeout | 10秒 | 请求处理服务超时时间 |
| keepalive | 60秒 | 连接池保持时间 |
| readbody | false | 是否读取body（没啥特殊需要建议不要瞎jb读body） |

## 转发说明

Middleman 插件会将原始请求的信息Encode为一段json发送给处理服务，处理服务需要接收这段Json并处理，字段和相关说明如下：

| 字段 | 说明 |
| - | - |
| headers | 原始请求头部信息，附赠请求的`uri`和`method` |
| url_args | 原始请求的参数信息 |
| body_data | 原始请求的body信息 |

Middleman 插件对于处理服务的返回仅判断其HTTP状态码，小于 299 忽略返回内容，直接允许原始请求通过；大于 299 则直接将处理服务的返回抛给客户端。

## Author
Panagis Tselentis

## License
<pre>
The MIT License (MIT)
=====================

Copyright (c) 2015 Panagis Tselentis

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
</pre>