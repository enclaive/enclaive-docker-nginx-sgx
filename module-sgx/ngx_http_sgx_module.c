#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>

#include <stdbool.h>
#include <openssl/sha.h>

static bool sgx_salted_sha512(u_char *value, long value_length, u_char *salt, long salt_length, u_char *md);

static ngx_int_t ngx_http_sgx_add_variables(ngx_conf_t *cf);
static ngx_int_t ngx_http_sgx_add_x_forwarded_for_variable(ngx_http_request_t *r, ngx_http_variable_value_t *v, uintptr_t data);

static ngx_http_module_t  ngx_http_sgx_module_ctx = {
    ngx_http_sgx_add_variables,            /* preconfiguration */
    NULL,                                  /* postconfiguration */

    NULL,                                  /* create main configuration */
    NULL,                                  /* init main configuration */

    NULL,                                  /* create server configuration */
    NULL,                                  /* merge server configuration */

    NULL,                                  /* create location configuration */
    NULL                                   /* merge location configuration */
};


ngx_module_t  ngx_http_sgx_module = {
    NGX_MODULE_V1,
    &ngx_http_sgx_module_ctx,              /* module context */
    NULL,                                  /* module directives */
    NGX_HTTP_MODULE,                       /* module type */
    NULL,                                  /* init master */
    NULL,                                  /* init module */
    NULL,                                  /* init process */
    NULL,                                  /* init thread */
    NULL,                                  /* exit thread */
    NULL,                                  /* exit process */
    NULL,                                  /* exit master */
    NGX_MODULE_V1_PADDING
};

static ngx_http_variable_t ngx_http_sgx_vars[] = {
    { ngx_string("sgx_add_x_forwarded_for"), NULL,
      ngx_http_sgx_add_x_forwarded_for_variable, 0, NGX_HTTP_VAR_NOHASH, 0 },
      ngx_http_null_variable
};

static ngx_int_t
ngx_http_sgx_add_variables(ngx_conf_t *cf)
{
    ngx_http_variable_t  *var, *v;

    for (v = ngx_http_sgx_vars; v->name.len; v++) {
        var = ngx_http_add_variable(cf, &v->name, v->flags);
        if (var == NULL) {
            return NGX_ERROR;
        }

        var->get_handler = v->get_handler;
        var->data = v->data;
    }

    return NGX_OK;
}

static ngx_int_t
ngx_http_sgx_add_x_forwarded_for_variable(ngx_http_request_t *req,
    ngx_http_variable_value_t *var, uintptr_t data)
{
    size_t             len, addr_len;
    u_char            *p, *q, *addr;
    ngx_uint_t         i, count;
    ngx_table_elt_t  **headers;

    var->valid = 1;
    var->no_cacheable = 0;
    var->not_found = 0;

    count = req->headers_in.x_forwarded_for.nelts;
    headers = req->headers_in.x_forwarded_for.elts;

    len = 0;

    for (i = 0; i < count; i++) {
        len += headers[i]->value.len + sizeof(", ") - 1;
    }

    // TODO read from provisioned secret file
    u_char salt[] = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC";
    u_char hash[SHA512_DIGEST_LENGTH];
    sgx_salted_sha512(req->connection->addr_text.data, req->connection->addr_text.len, salt, 32, hash);

    q = addr = ngx_pnalloc(req->pool, 39 + 1);

    if (addr == NULL) {
        return NGX_ERROR;
    }

    q = ngx_copy(q, "fd00", 4);

    for (i = 0; i < 7; i++) {
        *q++ = ':';
        q += snprintf((char *) q, 5, "%x%x", *(hash + i * 2), *(hash + i * 2 + 1));
    }

    ngx_memcpy(q, "", 1);

    addr_len = ngx_strlen(addr);

    if (len == 0) {
        var->len = addr_len;
        var->data = addr;
        return NGX_OK;
    }

    len += addr_len;

    p = ngx_pnalloc(req->pool, len);
    if (p == NULL) {
        return NGX_ERROR;
    }

    var->len = len;
    var->data = p;

    for (i = 0; i < count; i++) {
        p = ngx_copy(p, headers[i]->value.data, headers[i]->value.len);
        *p++ = ','; *p++ = ' ';
    }

    ngx_memcpy(p, addr, addr_len);

    return NGX_OK;
}

static bool
sgx_salted_sha512(u_char *value, long value_length, u_char *salt, long salt_length, u_char *md)
{
    SHA512_CTX context;

    if(!SHA512_Init(&context))
        return false;

    if(!SHA512_Update(&context, value, value_length))
        return false;

    if(!SHA512_Update(&context, salt, salt_length))
        return false;

    if(!SHA512_Final(md, &context))
        return false;

    return true;
}
