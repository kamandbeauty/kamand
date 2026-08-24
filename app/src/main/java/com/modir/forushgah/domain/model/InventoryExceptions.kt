package com.modir.forushgah.domain.model

/**
 * Thrown when an inventory operation would drive stock below zero.
 * Default app behavior (per Phase 2 spec) is to REJECT such operations —
 * negative stock is never silently allowed. A future "allow negative stock"
 * setting, if added, must be an explicit configurable toggle, not a fallback.
 */
class InsufficientStockException(
    val productId: Long,
    val requested: Int,
    val available: Int,
) : Exception("موجودی کافی نیست: درخواست $requested، موجودی فعلی $available")
