package com.vikstudios.artura.data

import coil.intercept.Interceptor
import coil.network.HttpException
import coil.request.ErrorResult
import coil.request.ImageResult
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap

/**
 * Loading of the catalog pictures (same behaviour as the iOS ImageStore):
 * - a picture asked for twice at the same time (preload + card on screen) is downloaded once:
 *   the second request waits for the first, then reads it from the cache;
 * - a few retries on network errors and server hiccups (not on a missing picture).
 */
class CatalogImageInterceptor : Interceptor {
    private val locks = ConcurrentHashMap<String, Mutex>()

    override suspend fun intercept(chain: Interceptor.Chain): ImageResult {
        val url = chain.request.data as? String
        if (url == null || !url.startsWith("http")) return chain.proceed(chain.request)
        return locks.getOrPut(url) { Mutex() }.withLock {
            var result = chain.proceed(chain.request)
            var attempt = 1
            while (result is ErrorResult && attempt < 3 && retryable(result.throwable)) {
                delay(1000L * attempt)
                result = chain.proceed(chain.request)
                attempt++
            }
            result
        }
    }

    private fun retryable(error: Throwable): Boolean = when (error) {
        is HttpException -> error.response.code.let { it >= 500 || it == 408 || it == 429 }
        is IOException -> true
        else -> false
    }
}
